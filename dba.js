(function ($) {

$(document).ready(function() {
  $('#dba_conn').change(function() {
    var F = document.DF;
    F.method = 'get';
    F.refresh.value = "1";
    F.submit();
  });
});

function go(p,sql) {
  alert(sql)
  var F = document.DF;
  F.p.value = p;
  if (sql) {
    F.q.value = sql;
  }
  F.submit();
}

function ays() {
  return confirm('Are you sure to continue?');
}

function chksql() {
  var F = document.DF;
  if (/^\s*(?:delete|drop|truncate|alter)/.test(F.q.value)) {
    return ays();
  }
}

function tmv(tr) {
  tr.sc = tr.className;
  tr.className = 'h';
}

function tmo(tr) {
  tr.className = tr.sc;
}

function tc(tr) {
  tr.className = 's';
  tr.sc = 's';
}

function after_load() {
}
  
})(jQuery);
