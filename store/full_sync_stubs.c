/* Request durable sync for the household writer (user decision 2026-10-21).
   On macOS use F_FULLFSYNC to request a drive-cache flush, not just fsync(2).
   Elsewhere use fsync(2). These requests are not a physical power-loss test. */
#include <fcntl.h>
#include <unistd.h>
#include <caml/mlvalues.h>
#include <caml/unixsupport.h>

value bakhlo_full_sync(value fd)
{
#ifdef F_FULLFSYNC
  if (fcntl(Int_val(fd), F_FULLFSYNC) == -1) uerror("fcntl(F_FULLFSYNC)", Nothing);
#else
  if (fsync(Int_val(fd)) == -1) uerror("fsync", Nothing);
#endif
  return Val_unit;
}

/* Send a file's bytes to the drive and keep them ordered before later writes,
   without waiting for the drive cache: F_BARRIERFSYNC on macOS, fsync(2)
   elsewhere. A full sync must still follow before anything is reported. */
value bakhlo_barrier_sync(value fd)
{
#ifdef F_BARRIERFSYNC
  if (fcntl(Int_val(fd), F_BARRIERFSYNC) == -1) uerror("fcntl(F_BARRIERFSYNC)", Nothing);
#else
  if (fsync(Int_val(fd)) == -1) uerror("fsync", Nothing);
#endif
  return Val_unit;
}
