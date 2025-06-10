/*
Jeroen's Chmod Calculator- By Jeroen Vermeulen of Alphamega Hosting <jeroen@alphamegahosting.com> 
Visit http://www.javascriptkit.com for this script and more
This notice must stay intact
*/
 
function octalchange() 
{
	var val = document.chmod.t_total.value;
	var extrabin = parseInt(val.charAt(0)).toString(2);
	while (extrabin.length<2) { extrabin="0"+extrabin; };
	var ownerbin = parseInt(val.charAt(1)).toString(2);
	while (ownerbin.length<4) { ownerbin="0"+ownerbin; };
	var groupbin = parseInt(val.charAt(2)).toString(2);
	while (groupbin.length<4) { groupbin="0"+groupbin; };
	var otherbin = parseInt(val.charAt(3)).toString(2);
	while (otherbin.length<4) { otherbin="0"+otherbin; };
	document.chmod.sticky.checked = parseInt(extrabin.charAt(1)); 
	document.chmod.setgid.checked = parseInt(extrabin.charAt(0)); 
	document.chmod.owner4.checked = parseInt(ownerbin.charAt(1)); 
	document.chmod.owner2.checked = parseInt(ownerbin.charAt(2));
	document.chmod.owner1.checked = parseInt(ownerbin.charAt(3));
	document.chmod.group4.checked = parseInt(groupbin.charAt(1)); 
	document.chmod.group2.checked = parseInt(groupbin.charAt(2));
	document.chmod.group1.checked = parseInt(groupbin.charAt(3));
	document.chmod.other4.checked = parseInt(otherbin.charAt(1)); 
	document.chmod.other2.checked = parseInt(otherbin.charAt(2));
	document.chmod.other1.checked = parseInt(otherbin.charAt(3));
	calc_chmod(1);
};

function calc_chmod(nototals)
{
  var users = new Array("owner", "group", "other");
  var totals = new Array("","","","");
  var syms = new Array("","","");

	if (document.chmod['sticky'].checked == true) { totals[0] = 1; } else { totals[0] = 0; }
	if (document.chmod['setgid'].checked == true) { totals[0] = totals[0] + 2; }

	for (var i=0; i<users.length; i++)
	{
	  var user=users[i];
		var field4 = user + "4";
		var field2 = user + "2";
		var field1 = user + "1";
		//var total = "t_" + user;
		var symbolic = "sym_" + user;
		var number = 0;
		var sym_string = "";
	
		if (document.chmod[field4].checked == true) { number += 4; }
		if (document.chmod[field2].checked == true) { number += 2; }
		if (document.chmod[field1].checked == true) { number += 1; }
	
		if (document.chmod[field4].checked == true) {
			sym_string += "r";
		} else {
			sym_string += "-";
		}
		if (document.chmod[field2].checked == true) {
			sym_string += "w";
		} else {
			sym_string += "-";
		}
		if (document.chmod[field1].checked == true) {
			sym_string += "x";
		} else {
			sym_string += "-";
		}
	
		totals[i + 1] = totals[i + 1]+number;
		syms[i] =  syms[i]+sym_string;
	
  };

	if (!nototals) document.chmod.t_total.value = totals[0] + totals[1] + totals[2] + totals[3];
	document.chmod.sym_total.value = "-" + syms[0] + syms[1] + syms[2];
}
window.onload=octalchange
