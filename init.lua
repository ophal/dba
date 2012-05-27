--[[
  Database Administration module.

  Based on PHP Mini Admin (c) 2004-2012 Oleg Savchuk http://osalabs.com
  Version 1.8.120510 - osalabs@gmail.com
  Site:   http://phpminiadmin.sourceforge.net
]]

local env = env
local add_js, add_css, base_path = add_js, add_css, base_path
local ophal, rawset, pairs, math = ophal, rawset, pairs, math
local empty, _REQUEST, tonumber = seawolf.variable.empty, _GET, tonumber
local debug, settings, unpack = debug, settings, unpack
local tins, tcon, slen = table.insert, table.concat, string.len
local trim, microtime = seawolf.text.trim, microtime
local explode, substr = seawolf.text.explode, seawolf.text.substr
local preg_match, strlen = seawolf.text.preg_match, string.len
local preg_replace = seawolf.text.preg_replace
local str_replace = seawolf.text.str_replace
local htmlspecialchars = seawolf.text.htmlspecialchars
local PREG_OFFSET_CAPTURE = 256

module [[ophal.modules.dba]]

ophal.modules.dba.version = [[0.1-alpha1]]

local db_current, db_connect, db_query, db_name, db_conn
local db_connections = {}
local out_message = [[]]
local reccount = 0
local err_msg = [[]]
local SQLq = trim(_REQUEST.query) or [[]]
local sqldr = {}
local self = base_path .. [[admin/build/database]]
local ACCESS_PWD = [[]]
local dbh = [[]]
local VERSION = [[]]
local MAX_ROWS_PER_PAGE = 50
local D = [[]]
local insql_done = 0
local is_limited_sql = 0
local is_sht = false
local time_all = 0
local LFILE = 0
local page_ = tonumber(_REQUEST.p) or 0

function configure()
  db_connect = env.db_connect
  db_query = env.db_query
  db_conn = _REQUEST.conn
  if settings.db[db_conn] ~= nil then
    db_name = settings.db[db_conn].database
  end

  -- Default query
  if not empty(_REQUEST.refresh) and not empty(db_name) and empty(SQLq) then
    SQLq = [[show tables]]
  end

  -- Filter databases allowed for DBA
  for k, v in pairs(settings.db) do
    if v.dba then
      rawset(db_connections, k, v)
    end
  end

  -- Default MAX_ROWS_PER_PAGE
  if settings.dba and settings.dba.MAX_ROWS_PER_PAGE then
    MAX_ROWS_PER_PAGE = settings.dba.MAX_ROWS_PER_PAGE
  end
end

--[[
  Implements hook menu().
]]
function menu()
  local items = {}
  items['admin/build/database'] = {
    title = [[Database administrator]],
    page_callback = [[page]],
  }

  return items
end

--[[
  Return all the rows of given SQL query.
]]
function db_array(sql, skiperr) -- array of rows
  if empty(skiperr) then skiperr = 0 end

  local rows = {}

  local rs = db_query(sql) -- TODO: skip query errors
  for row in rs:rows(true) do
    tins(rows, row)
  end

  return rows
end

function microtime_float()
  local usec, sec = unpack(explode([[ ]], microtime()))
  return tonumber(usec) + tonumber(sec)
end

function get_conn_select(sel_)
  local output = {}

  for k, v in pairs(db_connections) do
    rawset(output, #output + 1, ([[<option value="%s"%s>%s (%s)</option>]]):format(k, (sel_ and sel_ == v.database) and [[selected]] or [[]], k, v.driver))
  end

  return ([[<select name="conn" onChange="frefresh()"><option value=""> - none -</option>%s</select>]]):format(tcon(output))
end

--~ function get_db_select(sel_)
  --~ local output, first_row, rs = {}
--~ 
  --~ rs = db_query([[show databases]])
--~ 
  --~ if rs ~= nil then
    --~ for row in rs:rows(true) do
      --~ rawset(output, #output + 1, ([[<option value="%s"%s>%s</option>]]):format(row.Database, (sel_ and sel_ == row.Database) and [[selected]] or [[]], row.Database))
    --~ end
  --~ end
--~ 
  --~ return ([[<select name="db" onChange="frefresh()"><option value="">- none -</option>%s</select>]]):format(tcon(output))
--~ end

function page_header()
  add_css [[modules/dba/dba.css]]
  add_js [[modules/dba/dba.js]]

  local output = {}

  rawset(output, #output + 1, ([[<div id="dba">
<form method="post" name="DF" action="%sadmin/build/database" enctype="multipart/form-data">
<input type="hidden" name="refresh" value="">
<input type="hidden" name="p" value="">

<div class="inv">
<a href="http://gitorious.org/ophal/dba" target="_blank"><b>DBA %s</b></a>
|
Connections: %s
]]):format(base_path, ophal.modules.dba.version, get_conn_select(db_conn), base_path))

  if not empty(db_conn) then
    rawset(output, #output + 1, ([[
|
&#183;<a href="%s?conn=%s&query=show+databases">show databases</a>]]):format(self, db_conn))
  end

  if not empty(db_name) then
    local z = ([[ &#183;<a href="%s&conn=%s]]):format(self, db_conn)
    rawset(output, #output + 1, ([[%s&query=show+tables">show tables</a>
%s&query=show+table+status">status</a>
%s&shex=1">export</a>
%s&shim=1">import</a>
]]):format(z, z, z, z))
  end

  if not empty(ACCESS_PWD) then
    rawset(output, #output + 1, ([[ | <a href="%sadmin/build/database?logoff=1">Logoff</a> ]]):format())
  end
  rawset(output, #output + 1, ([[
</div>
]]):format(base_path))

  rawset(output, #output + 1, ([[<div class="err">%s</div>]]):format(err_msg))

  return tcon(output)
end

function page_select(sth, q)
  local rc, is_shd, is_show_crt, w, headers, meta, swp, v
  local vq, vt, more, first_row, columns
  local reccount_ = 0
  local abtn = [[]]

  rc = {[[o]], [[e]]}
  sqldr = {}

  is_shd = not empty(preg_match([[^show databases]], q, nil, nil, nil, [[i]]))
  is_sht = not empty(preg_match([[^show tables]], q, nil, nil, nil, [[i]]))
  is_show_crt = not empty(preg_match([[^show create table]], q, nil, nil, nil, [[i]]))

  columns = sth:columns()
  --~ reccount = mysql_num_rows(sth) -- TODO

  w = [[width='100%' ]]
  if not empty(is_sht) or not empty(is_shd) then
    w = [[]]
    tins(sqldr, tcon{[[<div class='dot'>
&nbsp;MySQL Server:
&nbsp;&#183;<a href=']], self, [[?conn=]], db_conn, [[&query=show+variables'>Show Configuration Variables</a>
&nbsp;&#183;<a href=']], self, [[?conn=]], db_conn, [[&query=show+status'>Show Statistics</a>
&nbsp;&#183;<a href=']], self, [[?conn=]], db_conn, [[&query=show+processlist'>Show Processlist</a>
<br/>]],
      not empty(is_sht) and tcon{[[&nbsp;Database:&nbsp;&#183;<a href=']], self, [[&conn=]], db_conn, [[&query=show+table+status'>Show status</a>]]} or [[]],
    [[</div>]]})
  end
  if not empty(is_sht) then
    abtn = [[&nbsp;<input type='submit' value='Export' onclick="sht('exp')">
 <input type='submit' value='Drop' onclick="if(ays()){sht('drop')}else{return false}">
 <input type='submit' value='Truncate' onclick="if(ays()){sht('tunc')}else{return false}">
 <input type='submit' value='Optimize' onclick="sht('opt')">
 <b>selected tables</b>]]
    tins(sqldr, tcon{abtn, [[<input type='hidden' name='dosht' value="">]]})
  end

  tins(sqldr, tcon{[[<table border='0' cellpadding='1' cellspacing='1' ]], w, [[ class='res'>]]})
  headers = {[[<tr class='h'>]],
    not empty(is_sht) and [[<td><input type='checkbox' name='cball' value="" onclick='chkall(this)'></td>]] or [[]]}
  for _, v in pairs(columns) do
    tins(headers, tcon{[[<th>]], v, [[</th>]]})
  end
  tins(headers, tcon{
    --~ not empty(is_shd) and [[<th>show create database</th><th>show table status</th><th>show triggers</th>]] or [[]],
    not empty(is_sht) and [[<th>show create table</th><th>explain</th><th>indexes</th><th>export</th><th>drop</th><th>truncate</th><th>optimize</th><th>repair</th>]] or [[]],
  "</tr>\n"})
  tins(sqldr, tcon(headers))
  swp = false
  for row in sth:rows(true) do
    reccount_ = reccount_ + 1
    swp = not swp
    tins(sqldr, tcon{[[<tr class=']], rc[(swp and 1 or 0) + 1], [[' onmouseover='tmv(this)' onmouseout='tmo(this)' onclick='tc(this)'>]]})
    for i, k in pairs(columns) do
      v = row[k]; more = [[]]
      if is_sht and i == 1 and not empty(v) then
         vt = {[[<input type='checkbox' name='cb[]' value="`]], v, [[`"></td>]],
         [[<td><a href="]], self, [[?conn=]], db_conn, [[&query=select+*+from+`]], v, [[`">]], v, [[</a></td>]],
         [[<td>&#183;<a href="]], self, [[?conn=]], db_conn, [[&query=show+create+table+`]], v, [[`">sct</a></td>]],
         [[<td>&#183;<a href="]], self, [[?conn=]], db_conn, [[&query=explain+`]], v, [[`">exp</a></td>]],
         [[<td>&#183;<a href="]], self, [[?conn=]], db_conn, [[&query=show+index+from+`]], v, [[`">ind</a></td>]],
         [[<td>&#183;<a href="]], self, [[?conn=]], db_conn, [[&shex=1&t=`]], v, [[`">export</a></td>]],
         [[<td>&#183;<a href="]], self, [[?conn=]], db_conn, [[&query=drop+table+`]], v, [[`" onclick='return ays()'>dr</a></td>]],
         [[<td>&#183;<a href="]], self, [[?conn=]], db_conn, [[&query=truncate+table+`]], v, [[`" onclick='return ays()'>tr</a></td>]],
         [[<td>&#183;<a href="]], self, [[?conn=]], db_conn, [[&query=optimize+table+`]], v, [[`" onclick='return ays()'>opt</a></td>]],
         [[<td>&#183;<a href="]], self, [[?conn=]], db_conn, [[&query=repair+table+`]], v, [[`" onclick='return ays()'>rpr</a>]]}
      --~ elseif not empty(is_shd) and i == 1 and not empty(v) then
         --~ vt = {[[<a href="]], self, [[?conn=]] , v, [[&query=show+tables">]] , v, [[</a></td>]],
         --~ [[<td><a href="]], self, [[?conn=]] , v, [[&query=show+create+database+`]] , v, [[`">scd</a></td>]],
         --~ [[<td><a href="]], self, [[?conn=]] , v, [[&query=show+table+status">status</a></td>]],
         --~ [[<td><a href="]], self, [[?conn=]] , v, [[&query=show+triggers">trig</a></td>]]}
      else
        if v == nil then v = [[NULL]] end
        vt = {htmlspecialchars(v)}
      end
      if not empty(is_show_crt) then vt = {[[<pre>]], vt[1], [[</pre>]]} end
      tins(sqldr, [[<td>]]); tins(sqldr, tcon(vt)); tins(sqldr, (not slen(v) and [[<br />]] or [[]])); tins(sqldr, [[</td>]])
    end
    tins(sqldr, "</tr>\n")
  end

  reccount = reccount_

  tins(sqldr, "</table>\n"); tins(sqldr, abtn)
end

function page()
  configure()

  if not empty(db_connect(db_conn)) then
    time_start = microtime_float()

    if not empty(db_name) then
      -- TODO
      if not empty(_REQUEST.shex) then
        --~ print_export()
      elseif not empty(_REQUEST.doex) then
        --~ do_export()
      elseif not empty(_REQUEST.shim) then
        --~ print_import()
      elseif not empty(_REQUEST.doim) then
        --~ do_import()
      elseif not empty(_REQUEST.dosht) then
        --~ do_sht()
      elseif empty(_REQUEST.refresh) or not empty(preg_match([[^select|show|explain|desci]], SQLq, nil, nil, nil, [[i]])) then
        do_sql(SQLq) -- perform non-selet SQL only if not refresh (to avoid dangerous delete/drop)
      end
    else
      if not empty(_REQUEST.refresh) then
        do_sql([[show tables]])
      elseif not empty(preg_match([[^show\s+(?:databases|status|variables)]], SQLq, nil, nil, nil, [[i]])) then
        do_sql(SQLq)
      else
        err_msg = [[Select Database first]]
      end
    end
    time_all = math.ceil((microtime_float() - time_start) * 10000) / 10000
  end

  local output = {
    page_header(),
    [[

<div class="dot" style="padding:0 0 5px 20px">
SQL-query (or many queries separated by ";"):<br />
<textarea name="query" cols="70" rows="10" style="width:98%">]], SQLq, [[</textarea><br/>
<input type=submit name="GoSQL" value="Go" onclick="return chksql()" style="width:100px">&nbsp;&nbsp;
<input type=button name="Clear" value=" Clear " onClick="document.DF.q.value=''" style="width:100px">
</div>

<div class="dot" style="padding:5px 0 5px 20px">
Records: <b>]], reccount, [[</b> in <b>]], time_all, [[</b> sec<br />
<b>]], out_message, [[</b>
</div>

]],
    (not empty(is_limited_sql) and (not empty(page_) or reccount >= MAX_ROWS_PER_PAGE)) and
    tcon{[[<center>]], make_List_Navigation(page_, 10000, MAX_ROWS_PER_PAGE, [[javascript:go(%p%)]]), [[</center>]]} or [[]],
    [[
]],
    tcon(sqldr),
    [[

]],
    page_footer(),
  }

  return tcon(output)
end

function page_footer()
  return [[
</form>
<br/>
<br/>

<div align="right">
<small>Powered by <a href="http://gitorious.org/ophal/dba" target="_blank">DBA</a></small>
</div>
]]
end

function do_sql(q)
  SQLq = q

  if empty(do_multi_sql(q, [[]], 1)) then
    out_message = [[Error: ]] .. mysql_error(dbh)
  else
    if not empty(last_sth) and not empty(last_sql) then
      SQLq = last_sql
      if not empty(preg_match([[^select|show|explain|desc]], last_sql, nil, nil, nil, [[i]])) then
        if q ~= last_sql then out_message = [[Results of the last select displayed:]] end
        page_select(last_sth, last_sql)
      else
        reccount = last_sth:affected()
        out_message = [[Done.]]
        if not empty(preg_match([[^insert|replace]], last_sql, nil, nil, nil, [[i]])) then out_message = out_message .. [[ Last inserted id = ]] .. get_identity() end
        if not empty(preg_match([[^drop|truncate]], last_sql, nil, nil, nil, [[i]])) then do_sql([[show tables]]) end
      end
    end
  end
end

function do_multi_sql(insql, fname)
  --~ set_time_limit(600) -- TODO

  local sql, ochar, is_cmt, opos, cur_pos, i, clchar, clpos

  sql = {}
  ochar = [[]]
  is_cmt = [[]]
  insql_done = 0
  for str in function () return get_next_chunk(insql, fname) end do
    opos = -slen(ochar or [[]]) + 1
    cur_pos = 1
    i = slen(str)
    while  not empty(i) do
      i = i - 1
      if not empty(ochar) then
        clchar, clpos = get_close_char(str, opos + strlen(ochar), ochar)
        if not empty(clchar) then
          if ochar == [[--]] or ochar == [[#]] or not empty(is_cmt) then
            tins(sql, substr(str, cur_pos, opos - cur_pos))
          else
            tins(sql, substr(str, cur_pos, clpos + strlen(clchar) - cur_pos))
          end
          cur_pos = clpos + strlen(clchar)
          ochar = [[]]
          opos = 1
        else
          tins(sql, substr(str, cur_pos))
          break
        end
      else
        ochar, opos = get_open_char(str, cur_pos)
        if ochar == [[;]] then
          tins(sql, substr(str, cur_pos, opos - cur_pos + 1))
          if empty(do_one_sql(tcon(sql))) then return 0 end
          sql = {}
          cur_pos = opos + slen(ochar)
          ochar = [[]]
          opos = 1
        elseif empty(ochar) then
          tins(sql, substr(str, cur_pos))
          break
        else
          is_cmt = 0; if ochar == [[/*]] and substr(str, opos, 4) ~= [[/*!]] then is_cmt = 1 end
        end
      end
    end
  end

  if not empty(sql) then
    if not do_one_sql(tcon(sql)) then return 0 end
    sql = {}
  end

  return 1
end

-- read from insql var or file
function get_next_chunk(insql, fname)
  if not empty(insql) then
    if not empty(insql_done) then
      return nil
    else
      insql_done = 1
      return insql
    end
  end
  if empty(fname) then return nil end
  if empty(LFILE) then
    LFILE = fopen(fname, [[r+b]]) or die([[Can't open []] .. fname.. [[] file $!]])
  end
  return fread(LFILE, 64 * 1024)
end

function get_open_char(str, pos)
  local m, ochar, opos, r = {}

  r = preg_match([[(\/\*|^--|(?<=\s)--|#|'|\"|;)]], str, m, PREG_OFFSET_CAPTURE, pos)
  if not empty(r) then
    ochar = m.v[2][1]
    opos = m.v[2][2]
  end
  return ochar, opos
end

-- #RECURSIVE!
function get_close_char(str, pos, ochar)
  local m, aCLOSE, clchar, clpos, sl = {}

  aCLOSE = {
    ["'"] = [[(?<!\\\\)\'|(\\\\+)\']],
    ['"'] = [[(?<!\\\\)"]],
    ['/*'] = [[\*\/]],
    ['#'] = [[[\r\n]+]],
    ['--'] = [[[\r\n]+]],
  }
  if aCLOSE[ochar] and not empty(preg_match([[(]] .. aCLOSE[ochar] .. [[)]], str, m, PREG_OFFSET_CAPTURE, pos)) then
    clchar = m.v[2][1]
    clpos = m.v[2][2]
    if m.v[3] then
      sl = strlen(m.v[3][1])
    end
    if ochar == [[']] and sl then
      if sl % 2 then -- don't count as CLOSE char if number of slashes before ' ODD
        clchar, clpos = get_close_char(str, clpos + strlen(clchar), ochar)
      else
        clpos = clpos + strlen(clchar) - 1; clchar = [[']]; -- correction
      end
    end
  end
  return clchar, clpos
end

function do_one_sql(sql)
  sql = trim(sql)
  sql = preg_replace([[;$]], [[]], sql)
  if not empty(sql) then
    last_sql = sql; is_limited_sql = 0
    if not empty(preg_match([[^select]], sql, nil, nil, nil, [[i]])) and empty(preg_match([[limit +\d+]], sql, nil, nil, nil, [[i]])) then
      offset = page_ * MAX_ROWS_PER_PAGE
      sql = sql .. [[ LIMIT ]] .. offset .. [[,]] .. MAX_ROWS_PER_PAGE
      is_limited_sql = 1
    end
    last_sth = db_query(sql)
    return last_sth
  end
  return true
end

--[[
  $pg=int($_[0]);     #current page
  $all=int($_[1]);     #total number of items
  $PP=$_[2];      #number if items Per Page
  $ptpl=$_[3];      #page url /ukr/dollar/notes.php?page=    for notes.php
  $show_all=$_[5];           #print Totals?
]]
function make_List_Navigation(pg, all, PP, ptpl, show_all)
  if show_all == nil then show_all = [[]] end

  local n, sep, allp, pname, res, w, sg, sp, p_p

  n = [[&nbsp;]]
  sep = [[ ]] .. n .. [[|]] .. n .. '\n'
  if empty(PP) then PP = 10 end
  allp = math.floor(all/PP + 0.999999)

  pname = [[]]
  res = [[]]
  w = {[[Less]], [[More]], [[Back]], [[Next]], [[First]], [[Total]]}

  sp = pg - 2
  if sp < 0 then sp = 0 end
  if allp - sp < 5 and allp >= 5 then sp = allp - 5 end

  res = [[]]

  if sp > 0 then
    pname = pen(sp - 1, ptpl)
    res = res .. [[<a href=']] .. pname .. [['>]] .. w[1] .. [[</a>]]
    res = res .. sep
  end
  p_p = sp - 1
  while p_p < allp and p_p < sp + 5 do
    p_p = p_p + 1
    first_s = p_p * PP + 1
    last_s = (p_p + 1) * PP
    pname = pen(p_p, ptpl)
    if last_s > all then
     last_s = all
    end
    if p_p == pg then
     res = res .. [[<b>]] .. first_s .. [[..]] .. last_s .. [[</b>]]
    else
     res = res .. [[<a href=']] .. pname .. [['>]] .. first_s .. [[..]] .. last_s .. [[</a>]]
    end
    if p_p + 1 < allp then res = res .. sep end
  end
  if sp + 5 < allp then
    pname = pen(sp + 5, ptpl)
    res = res .. [[<a href=']] .. pname .. [['>]] .. w[2] .. [[</a>]]
  end
  res = res .. ' <br/>\n'

  if pg > 0 then
    pname = pen(pg - 1, ptpl)
    res = res .. [[<a href=']] ..  pname .. [['>]] .. w[3] .. [[</a> ]] .. n .. [[|]] .. n .. [[ ]]
    pname = pen(0, ptpl)
    res = res .. [[<a href=']] .. pname .. [['>]] .. w[5] .. [[</a>]]
  end
  if pg > 0 and pg + 1 < allp then res = res .. sep end
  if pg + 1 < allp then
    pname = pen(pg + 1, ptpl)
    res = res .. [[<a href=']] .. pname .. [['>]] .. w[4] .. [[</a>]]    
  end
  if not empty(show_all) then res = res .. [[ <b>(]] .. w[6] .. [[ - ]] .. all .. [[)</b> ]] end

  return res
end

function pen(p, np)
  if np == nil then np = [[]] end
  return str_replace([[%p%]], p, np)
end
