# Kousa Architecture Document

Kousa will roughly follow the HyperHypeBeast hexagonal, or
"functional core" architecture:

https://www.youtube.com/watch?v=yTkzNHF6rMs

Elixir contexts

1. `Beef` - Database, persistent state for Kousa
 - `Beef.Access` nonmutating queries
 - `Beef.Changesets` ingress validation logic
 - `Beef.Mutations` mutating queries
 - `Beef.Queries` composable Ecto.Query fragments
 - `Beef.Schemas` database table schemas
 - `Beef.Lenses` database struct logic
2. `Onion` - OTP-based transient state for Kousa & PubSub
3. `Broth` - Web interface and contexts
 - `Broth.Messages` - contracts for all ws I/O
4. `Kousa` - OTP Application, Business Logic, and common toolsets

NB: All of the module contexts will be part of the `:kousa` BEAM VM
application under the application supervision tree

## Boundaries

- Broth can call Kousa.
- Kousa can call Onion (and Beef)
- Onion can call Beef.
- Beef cannot call anything else.

### Exceptions:
- Beef Schemas (and Beef Changesets) are available to All.
- Kousa.Utils are available to All.

## Process Structure and Roles.
- Broth.SocketHandler maintains websocket state
- Onion.RoomSession maintains room state and is a read-cache for room db.
- Onion.UserSession maintains user state and is a read-cache for user db.
  - Keeping the DB mutations in the session guarantees serialization of the DB and
    limits the number of times we can have stale data cause a disruption.
- The only DB functions that should exist outside of a session is create room.