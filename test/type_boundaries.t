A well-typed external client compiles using only the public interfaces.

  $ book_client() { ocamlfind ocamlc -package zarith -I ../book_txt/.bakhlo_book_txt.objs/byte -c "$@"; }

An admitted book.txt is reached only by reading or changing one; its balances and
printed lines cannot be supplied by hand.

  $ cat >book_client.ml <<'EOF'
  > module T = Bakhlo_book_txt.Book_txt
  > let read text = Result.map (fun b -> T.print b) (T.read text)
  > EOF
  $ book_client book_client.ml
  $ cat >forged_book.ml <<'EOF'
  > module T = Bakhlo_book_txt.Book_txt
  > let forge (value : T.t) : T.book = { value; next = 0 }
  > EOF
  $ book_client forged_book.ml 2>error
  [2]
  $ grep -Eqi 'record|field|abstract|unbound' error

A store session can be read by callers, but its admitted book, file path and
revision cannot be replaced independently of the writer.

  $ store_client() { ocamlfind ocamlc -package base,zarith,sexplib0,unix -I ../store/.bakhlo_store.objs/byte -I ../household/.bakhlo_household.objs/byte -I ../book_txt/.bakhlo_book_txt.objs/byte -c "$@"; }
  $ cat >session_reader.ml <<'EOF'
  > let facts (session : Book_file.t) =
  >   (session.path, session.revision, session.book)
  > let reload = Book_file.reload
  > EOF
  $ store_client session_reader.ml
  $ cat >forged_session.ml <<'EOF'
  > let forge (session : Book_file.t) book =
  >   { session with book; path = "different-book.txt"; revision = "forged" }
  > EOF
  $ store_client forged_session.ml 2>error
  [2]
  $ grep -qi 'private' error && grep -q 'Book_file.t' error
