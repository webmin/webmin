/* filter_match: show/hide table row when match string in achor tag (<a>)
 * 28-Nov-2013: nawawi jamili <nawawi@rutweb.com>
 */

/* ie8 and below */
if ( !String.prototype.trim ) {  
    String.prototype.trim = function() {  
        return this.replace(/^\s+|\s+$/g,'');  
    };  
};

function filter_match(str, _cname, _match) {
    _cname = _cname || "filter_match";
    _match = _match || false;

    var show_hide = function(n,clear) {
        clear = clear || false;
        var ls = document.getElementsByTagName("tr");
        if ( ls.length > 0 ) {
            for(var x=0; x < ls.length; x++) {
                var tt=ls[x];
                var cl = tt.className;
                if ( !_match && cl !== _cname ) continue;
                if ( _match && cl.match(_cname) === null ) continue;
                if ( n === null ) {
                    if ( clear ) {
                        tt.style.display='';
                    } else {
                        tt.style.display='none';
                    }
                } else if ( x === n ) {
                    tt.style.display='';
                }
            }
        }
    };

    str = str.trim();
    if ( str !== '' ) {
        show_hide(null,false);
        var ls = document.getElementsByTagName("tr");
        if ( ls.length > 0 ) {
            for(var x=0; x < ls.length; x++) {
                var cl = ls[x].className;
                if ( !_match && cl !== _cname ) continue;
                if ( _match && cl.match(_cname) === null ) continue;
                var y = ls[x].getElementsByTagName("a");
                for(var t=0; t < y.length; t++) {
                    var strm = y[t].innerHTML;
                    strm = strm.toLowerCase();
                    if ( strm.match(str.toLowerCase()) ) {
                        show_hide(x);
                    }
                }
            }
        }
    } else {
        show_hide(null,true);
    }
};
/* show/hide filter box */
function filter_match_box(show) {
    show = show || true;
    if ( true ) {
        document.getElementById('filter_box').style.display='';
    } else {
       document.getElementById('filter_box').style.display='none';
    }
};

