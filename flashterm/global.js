function stormInit() {
	showFlash();
	var appendLinks = document.getElementsByTagName("a");
	for (var i = 0; i < appendLinks.length; i++) {
		if (appendLinks[i].rel == "append") {
			appendLinks[i].href += this.location;
		}
	}
}
