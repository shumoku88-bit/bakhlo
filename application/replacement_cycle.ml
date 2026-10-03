module Make (Key : sig
    type t
    val equal : t -> t -> bool
    include Base.Comparator.S with type t := t
  end) = struct
  let check ~successor ~starts =
    let rec walk completed visiting reversed id =
      if Base.Set.mem visiting id then
        let interior = Base.List.take_while reversed ~f:(fun seen -> not (Key.equal seen id)) in
        Error (id :: Base.List.append (Base.List.rev interior) [ id ])
      else if Base.Set.mem completed id then Ok (Base.Set.union completed visiting)
      else
        let visiting = Base.Set.add visiting id in
        match successor id with
        | None -> Ok (Base.Set.union completed visiting)
        | Some replacement -> (walk [@tailcall]) completed visiting (id :: reversed) replacement
    in
    Base.Result.map
      (Base.List.fold_result starts ~init:(Base.Set.empty (module Key))
        ~f:(fun completed id -> walk completed (Base.Set.empty (module Key)) [] id))
      ~f:(fun _ -> ())
  ;;
end
