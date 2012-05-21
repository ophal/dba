== Table of Contents ==

I.   What is Ophal?
II.  Roadmap
III. Configuration


== I. What is Ophal? ==

The DBA module is intended to handle the administration of databases in Ophal.
It started as a Lua port of phpMiniAdmin, within the Nutria project.


== II. Roadmap ==

1. Alpha
  Port all functionality from phpMyAdmin.

2. Beta
  ACL by role.

3. Release candidate
  Bugs fixing and performance improvements.

4. First stable release
  Maintenance release.


== III. Configuration ==

By default DBA has access to all databases configured in settings.lua. To
allow access to a database from DBA just set the option 'dba' to true.

Example:

  settings.db = {
    test = {
      driver = [[SQLite3]],
      database = [[db/test.db]],
      dba = true,
    }
  }

