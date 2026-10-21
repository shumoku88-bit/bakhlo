/* Durable sync for the household writer (user decision 2026-10-21).
   On macOS fsync(2) leaves data in the drive cache; F_FULLFSYNC flushes it, so a
   save shown as done survives power loss. Elsewhere fsync(2) is the durable call. */
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
