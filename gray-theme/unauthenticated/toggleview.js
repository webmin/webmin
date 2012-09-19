function toggleview (id1,id2) {
		var obj1 = document.getElementById(id1);
		var obj2 = document.getElementById(id2);
		(obj1.className=="itemshown") ? obj1.className="itemhidden" : obj1.className="itemshown"; 
		(obj1.className=="itemshown") ? obj2.innerHTML="<img border='0' src='images/open.gif' alt='[&ndash;]'>" : obj2.innerHTML="<img border='0' src='images/closed.gif' alt='[+]'>"; 
	}
