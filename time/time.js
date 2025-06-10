function timeInit(F) {
	secs = new Array();
	mins = new Array();
	hours = new Array();
	for(i=0; i<F.length; i++){
		secs[i]  = document.forms[F[i]].second;
		mins[i]  = document.forms[F[i]].minute;
		hours[i] = document.forms[F[i]].hour; }
}
function timeUpdate(F) {
	for(i=0; i<F.length; i++){
		s = parseInt(secs[i].selectedIndex);
		s = s ? s : 0;
		s = s+5;
		if( s>59 ){
			s -= 60;
			m = parseInt(mins[i].selectedIndex);
			m= m ? m : 0;
			m+=1;
			if( m>59 ){
				m -= 60;
				h = parseInt(hours[i].selectedIndex);
				h = h ? h : 0;
				h+=1;
				if( h>23 ){
					h -= 24;
				}
				hours[i].selectedIndex  = h;
			}
			mins[i].selectedIndex  = m;
		}
	secs[i].selectedIndex = s; }
	setTimeout('timeUpdate(F)', 5000);
}
function packNum(t) {
	return (t < 10 ? '0'+t : t);
}
