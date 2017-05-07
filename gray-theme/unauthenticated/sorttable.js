addEvent(window, "load", sortables_init);

var SORT_COLUMN_INDEX;

function sortables_init() {
     var lastAssignedId = 0;
    // Find all tables with class sortable and make them sortable
    if (!document.getElementsByTagName) return;
    tbls = document.getElementsByTagName("table");
    for (ti=0;ti<tbls.length;ti++) {
        thisTbl = tbls[ti];
	if (!thisTbl.id) {
      	    thisTbl.id = 'sortableTable'+(lastAssignedId++);
    	}
        if (((' '+thisTbl.className+' ').indexOf("sortable") != -1) && (thisTbl.id)) {
            //initTable(thisTbl.id);
            ts_makeSortable(thisTbl);
        }
    }
}

function ts_makeSortable(table) {
    if (table.rows && table.rows.length > 0) {
        var firstRow = table.rows[0];
    }
    if (!firstRow) return;
    
    // We have a first row: assume it's the header, and make its contents clickable links
    for (var i=0;i<firstRow.cells.length;i++) {
        var cell = firstRow.cells[i];
        var txt = ts_getInnerText(cell);
        cell.innerHTML = '<b><a href="#" class="sortheader" '+ 
        'onclick="ts_resortTable(this, '+i+');return false;">' + 
        txt+'<span class="sortarrow">&nbsp;&nbsp;&nbsp;</span></a></b>';
    }
}

function ts_getInnerText(el) {
	if (typeof el == "string") return el;
	if (typeof el == "undefined") { return el };
	if (el.innerText) return el.innerText;	//Not needed but it is faster
	var str = "";
	
	var cs = el.childNodes;
	var l = cs.length;
	for (var i = 0; i < l; i++) {
		switch (cs[i].nodeType) {
			case 1: //ELEMENT_NODE
				str += ts_getInnerText(cs[i]);
				break;
			case 3:	//TEXT_NODE
				str += cs[i].nodeValue;
				break;
		}
	}
	return str;
}

function ts_resortTable(lnk,clid) {
    // get the span
    var span;
    for (var ci=0;ci<lnk.childNodes.length;ci++) {
        if (lnk.childNodes[ci].tagName && lnk.childNodes[ci].tagName.toLowerCase() == 'span') span = lnk.childNodes[ci];
    }
    var spantext = ts_getInnerText(span);
    var td = lnk.parentNode;
    while(td.nodeName.toLowerCase() != 'td')
        td = td.parentNode;
    var column = typeof(clid) == 'undefined' ? td.cellIndex : clid;
    var table = getParent(td,'TABLE');
    
    // Work out a type for the column
    if (table.rows.length <= 1) return;
    var itm = ts_getInnerText(table.rows[1].cells[column]);
    sortfn = ts_sort_caseinsensitive;
    if (itm.match(/^\d\d[\/-]\d\d[\/-]\d\d\d\d$/)) sortfn = ts_sort_date;
    if (itm.match(/^\d\d[\/-]\S\S\S[\/-]\d\d\d\d$/)) sortfn = ts_sort_date;
    if (itm.match(/^\d\d[\/-]\d\d[\/-]\d\d$/)) sortfn = ts_sort_date;
    if (itm.match(/^[£$]/)) sortfn = ts_sort_currency;
    if (itm.match(/^[\d\.]+\s*(bytes|b|kb|tb|gb|mb)$/i)) sortfn = ts_sort_filesize;
    // Special cases for our mailbox lists
    if (itm.match(/^(Empty|Unlimited)$/)) sortfn = ts_sort_filesize;
    if (itm.match(/^[\d\.]+%?$/)) sortfn = ts_sort_numeric;
    if (itm.match(/^\d+\.\d+\.\d+\.\d+$/)) sortfn = ts_sort_ip;
    SORT_COLUMN_INDEX = column;
    var firstRow = new Array();
    var newRows = new Array();
    for (i=0;i<table.rows[0].length;i++) { firstRow[i] = table.rows[0][i]; }
    for (j=1;j<table.rows.length;j++) { newRows[j-1] = table.rows[j]; }

    newRows.sort(sortfn);

    if (span.getAttribute("sortdir") == 'down') {
        ARROW = '&nbsp;&nbsp;&uarr;';
        newRows.reverse();
        span.setAttribute('sortdir','up');
    } else {
        ARROW = '&nbsp;&nbsp;&darr;';
        span.setAttribute('sortdir','down');
    }
    
    // We appendChild rows that already exist to the tbody, so it moves them rather than creating new ones
    // don't do sortbottom rows
    for (i=0;i<newRows.length;i++) { if (!newRows[i].className || (newRows[i].className && (newRows[i].className.indexOf('sortbottom') == -1))) table.tBodies[0].appendChild(newRows[i]);}
    // do sortbottom rows only
    for (i=0;i<newRows.length;i++) { if (newRows[i].className && (newRows[i].className.indexOf('sortbottom') != -1)) table.tBodies[0].appendChild(newRows[i]);}
    
    // Delete any other arrows there may be showing
    var allspans = document.getElementsByTagName("span");
    for (var ci=0;ci<allspans.length;ci++) {
        if (allspans[ci].className == 'sortarrow') {
            if (getParent(allspans[ci],"table") == getParent(lnk,"table")) { // in the same table as us?
                allspans[ci].innerHTML = '&nbsp;&nbsp;&nbsp;';
            }
        }
    }
        
    span.innerHTML = ARROW;
}

function getParent(el, pTagName) {
	if (el == null) return null;
	else if (el.nodeType == 1 && el.tagName.toLowerCase() == pTagName.toLowerCase())	// Gecko bug, supposed to be uppercase
		return el;
	else
		return getParent(el.parentNode, pTagName);
}
function ts_sort_date(a,b) {
    // y2k notes: two digit years less than 50 are treated as 20XX, greater than 50 are treated as 19XX
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]);
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]);
    if (aa.length == 10) {
        // yyyy/mm/dd format
        dt1 = aa.substr(6,4)+aa.substr(3,2)+aa.substr(0,2);
    } else if (aa.length == 11) {
        // dd/mon/yyyy format
        dt1 = aa.substr(7,4)+ts_month_num(aa.substr(3,3))+aa.substr(0,2);
    } else {
        yr = aa.substr(6,2);
        if (parseInt(yr) < 50) { yr = '20'+yr; } else { yr = '19'+yr; }
        dt1 = yr+aa.substr(3,2)+aa.substr(0,2);
    }
    if (bb.length == 10) {
        dt2 = bb.substr(6,4)+bb.substr(3,2)+bb.substr(0,2);
    } else if (bb.length == 11) {
        // dd/mon/yyyy format
        dt2 = bb.substr(7,4)+ts_month_num(bb.substr(3,3))+bb.substr(0,2);
    } else {
        yr = bb.substr(6,2);
        if (parseInt(yr) < 50) { yr = '20'+yr; } else { yr = '19'+yr; }
        dt2 = yr+bb.substr(3,2)+bb.substr(0,2);
    }
    if (dt1==dt2) return 0;
    if (dt1<dt2) return -1;
    return 1;
}

function ts_month_num(month) {
  month = month.toLowerCase();
  return month == 'jan' ? '01' :
	 month == 'feb' ? '02' :
	 month == 'mar' ? '03' :
	 month == 'apr' ? '04' :
	 month == 'may' ? '05' :
	 month == 'jun' ? '06' :
	 month == 'jul' ? '07' :
	 month == 'aug' ? '08' :
	 month == 'sep' ? '09' :
	 month == 'oct' ? '10' :
	 month == 'nov' ? '11' :
	 month == 'dec' ? '12' : '00';
}

function ts_sort_currency(a,b) { 
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]).replace(/[^0-9.]/g,'');
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]).replace(/[^0-9.]/g,'');
    return parseFloat(aa) - parseFloat(bb);
}

// handles file sizes, simple numerics, and Unlimited/Empty/None special cases
function ts_sort_filesize(a,b) {
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]).toLowerCase();
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]).toLowerCase();

    if (aa.length == 0) return -1;
    else if (bb.length == 0) return 1;

    var regex = /^([\d\.]*|none|empty|unlimited)\s*(bytes|b|kb|tb|gb|mb)?$/i;
    matchA = aa.match(regex);
    matchB = bb.match(regex);

    // Give file size class an integer value, if we don't already have one
    if (matchA[1] == 'none') valA = -999;
    else if (matchA[1] == 'empty') valA = 0;
    else if (matchA[1] == '0') valA = 0;
    else if (matchA[1] == 'unlimited') valA = 999;
    else if (matchA[2] == 'b' || matchA[2] == 'bytes') valA = 1;
    else if (matchA[2] == undefined || matchA[2] == '') valA = 1;
    else if (matchA[2] == 'kb') valA = 2;
    else if (matchA[2] == 'mb') valA = 3;
    else if (matchA[2] == 'gb') valA = 4;
    else if (matchA[2] == 'tb') valA = 5;

    if (matchB[1] == 'none') valB = -999;
    else if (matchB[1] == 'empty') valB = 0;
    else if (matchB[1] == '0') valB = 0;
    else if (matchB[1] == 'unlimited') valB = 999;
    else if (matchB[2] == 'b' || matchB[2] == 'bytes') valB = 1;
    else if (matchB[2] == undefined || matchB[2] == '') valB = 1;
    else if (matchB[2] == 'kb') valB = 2;
    else if (matchB[2] == 'mb') valB = 3;
    else if (matchB[2] == 'gb') valB = 4;
    else if (matchB[2] == 'tb') valB = 5;

    if (valA == valB) {
			if ( isNaN(matchA[1])) return -1;
      if ( isNaN(matchB[1])) return 1;
      // Files are in the same size class kb/gb/mb/etc
      // just do a numeric sort on the file size
			return matchA[1]-matchB[1];
    } else if (valA < valB) {
      return -1;
    } else if (valA > valB) {
      return 1;
    }
}

function ts_sort_numeric(a,b) { 
    aa = parseFloat(ts_getInnerText(a.cells[SORT_COLUMN_INDEX]));
    if (isNaN(aa)) aa = 0;
    bb = parseFloat(ts_getInnerText(b.cells[SORT_COLUMN_INDEX])); 
    if (isNaN(bb)) bb = 0;
    return aa-bb;
}

function ts_sort_caseinsensitive(a,b) {
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]).toLowerCase();
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]).toLowerCase();
    if (aa==bb) return 0;
    if (aa<bb) return -1;
    return 1;
}

function ts_sort_ip(a,b) {
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]).toLowerCase();
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]).toLowerCase();
    var regexp = /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;
    var matchA = aa.match(regexp);
    var matchB = bb.match(regexp);
    return !matchA ? -1 :
	   !matchB ? 1 :
	   parseInt(matchA[1]) < parseInt(matchB[1]) ? -1 :
           parseInt(matchA[1]) > parseInt(matchB[1]) ? 1 :
	   parseInt(matchA[2]) < parseInt(matchB[2]) ? -1 :
           parseInt(matchA[2]) > parseInt(matchB[2]) ? 1 :
	   parseInt(matchA[3]) < parseInt(matchB[3]) ? -1 :
           parseInt(matchA[3]) > parseInt(matchB[3]) ? 1 :
	   parseInt(matchA[4]) < parseInt(matchB[4]) ? -1 :
           parseInt(matchA[4]) > parseInt(matchB[4]) ? 1 : 0;
}

function ts_sort_default(a,b) {
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]);
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]);
    if (aa==bb) return 0;
    if (aa<bb) return -1;
    return 1;
}


function addEvent(elm, evType, fn, useCapture)
// addEvent and removeEvent
// cross-browser event handling for IE5+,  NS6 and Mozilla
// By Scott Andrew
{
  if (elm.addEventListener){
    elm.addEventListener(evType, fn, useCapture);
    return true;
  } else if (elm.attachEvent){
    var r = elm.attachEvent("on"+evType, fn);
    return r;
  } else {
    alert("Handler could not be removed");
  }
} 
