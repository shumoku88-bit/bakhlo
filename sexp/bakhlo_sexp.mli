module Crc32 = Crc32

module Book = Book
(** Pure outer versioned S-expression adapter; no filesystem/publication authority. *)

module Daily_book = Daily_book
module Year_read = Year_read
(** Opt-in validation only; no production selection source or annual store. *)

module Records_book = Records_book

module Durable_append = Durable_append



