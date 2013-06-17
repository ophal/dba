== Table of Contents ==

I.   What is DBA?
II.  Roadmap
III. Configuration


== I. What is DBA? ==

The DBA module is intended to handle the administration of databases in
Ophal[1]. This project started as a Lua port of phpMiniAdmin[2], within
the Nutria[3] project.

[1] http://ophal.org
[2] http://phpminiadmin.sourceforge.net
[3] http://gitorious.org/nutria


== II. Roadmap ==

1. Alpha
  Port all functionality from phpMiniAdmin.

2. Beta
  ACL by role.

3. Release candidate
  Bugs fixing and performance improvements.

4. First stable release
  Maintenance release.


== III. Configuration ==

1. Settings
  DBA module uses extra Seawolf and Lua libraries, you need to add them
  manually to the sandbox in 'settings.lua', to do so just add following lines:

  env.preg_match = require 'seawolf.text.preg'.match
  env.preg_replace = require 'seawolf.text.preg'.match
  env.microtime = require 'seawolf.calendar'.microtime

  In order to customize the option MAX_ROWS_PER_PAGE just add the
  following to your settings.lua:

  settings.dba = {
    MAX_ROWS_PER_PAGE = 100, -- default value: 50
  }


2. Database access
  By default DBA has no access to databases configured in settings.lua.
  In order to allow access to a database from DBA just set the option
  'dba' to true.

  Example:

  settings.db = {
    test = {
      driver = [[SQLite3]],
      database = [[db/test.db]],
      dba = true,
    }
  }

