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
