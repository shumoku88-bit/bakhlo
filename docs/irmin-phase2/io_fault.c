/* macOS research child only: interpose writes/fsync on explicitly selected trial
 * repository descriptors AFTER OCaml arms the hook. Never touches other paths.
 * This observes process/syscall failures, NOT power-loss persistence. */
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
#include <signal.h>
static unsigned hits;
static int short_pending;
static int selected(int fd, const char *op, char *path) {
  const char *armed=getenv("TRIAL_FAULT_ARMED"), *root=getenv("TRIAL_FAULT_ROOT");
  if (!armed || strcmp(armed,"1") || !root || !*root) return 0;
  if (fcntl(fd,F_GETPATH,path)<0) return 0;
  size_t n=strlen(root);
  if (strncmp(path,root,n) || path[n]!='/') return 0;
  const char *filter=getenv("TRIAL_FAULT_FILE");
  if (filter && *filter && !strstr(path+n,filter)) return 0;
  const char *kind=getenv("TRIAL_FAULT_OP");
  if (kind && *kind && strcmp(kind,op)) return 0;
  return 1;
}
static void note(const char *op, const char *path, size_t n, const char *action) {
  char buf[PATH_MAX+200];
  int len=snprintf(buf,sizeof(buf),"io-hook\t%s\t%u\t%zu\t%s\t%s\n",op,hits,n,action,path);
  if (len>0 && len<(int)sizeof(buf)) (void)write(STDERR_FILENO,buf,(size_t)len);
}
static int decision(int fd, const char *op, size_t n) {
  char path[PATH_MAX];
  if (!selected(fd,op,path)) return 0;
  hits++;
  const char *action=getenv("TRIAL_FAULT_ACTION"); if (!action) action="trace";
  note(op,path,n,action);
  if (!strcmp(action,"trace")) return 0;
  unsigned at=1; const char *index=getenv("TRIAL_FAULT_N"); if(index) at=(unsigned)strtoul(index,0,10);
  if (short_pending) {errno=EIO;return 1;}
  if(hits!=at) return 0;
  if(!strcmp(action,"eio")) {errno=EIO;return 1;}
  if(!strcmp(action,"short-eio")) {short_pending=1;return 2;}
  if(!strcmp(action,"partial-kill")) return 3;
  return 0;
}
static ssize_t trial_write(int fd,const void *buf,size_t n) {
  int d=decision(fd,"write",n);
  if(d==1) return -1;
  if(d==2 || d==3) {
    ssize_t r=write(fd,buf,n>1?n/2:1);
    if(d==3) {kill(getpid(),SIGKILL);_exit(99);} return r;
  }
  return write(fd,buf,n);
}
static ssize_t trial_pwrite(int fd,const void *buf,size_t n,off_t off) {
  int d=decision(fd,"write",n);
  if(d==1) return -1;
  if(d==2 || d==3) {
    ssize_t r=pwrite(fd,buf,n>1?n/2:1,off);
    if(d==3) {kill(getpid(),SIGKILL);_exit(99);} return r;
  }
  return pwrite(fd,buf,n,off);
}
static int trial_fsync(int fd) {
  int d=decision(fd,"fsync",0); if(d==1) return -1;
  return fsync(fd);
}
#define INTERPOSE(new_fn,old_fn) \
  __attribute__((used)) static struct {const void *replacement;const void *replacee;} pair_##old_fn \
  __attribute__((section("__DATA,__interpose")))={(const void*)(unsigned long)&new_fn,(const void*)(unsigned long)&old_fn};
INTERPOSE(trial_write,write)
INTERPOSE(trial_pwrite,pwrite)
INTERPOSE(trial_fsync,fsync)
