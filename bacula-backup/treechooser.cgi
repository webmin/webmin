#!/usr/local/bin/perl
# treechooser.cgi
# Outputs HTML for a javascript file-chooser tree

require './bacula-backup-lib.pl';
&PrintHeader();
&ReadParse();

$shortest = "/";
$in{'job'} =~ s/^(.*)_(\d+)$/$2/g;
print <<EOF;
<html>
<head>
	<title>$text{'tree_title'}</title>
	<link rel="stylesheet" href="jstree/themes/default/style.min.css" />
	<style>
		body {
			margin: 0;
			font-family: Arial, Helvetica, sans-serif;
			font-size: 0.8em;
		}
		.buttons {
			display: flex;
			flex-flow: row nowrap;
			justify-content: center;
			padding: 5px;
		}
		.main-container {
			display: flex;
			flex-flow: column nowrap;
			height: 100%;
		}
		.spaced-button {
			margin: 5px;
		}
		#jstree {
			flex: 1;
			margin: 10px;
			margin-bottom: 0px;
			border: thin solid gray;
			overflow: auto;
		}
	</style>
</head>

<body>

<div class="main-container">
	<div id="jstree"></div>
	<div class="buttons">
		<button id="confirm" class="ui-button ui-widget ui-corner-all spaced-button">OK</button>
		<button id="cancel"  class="ui-button ui-widget ui-corner-all spaced-button">Cancel</button>
	</div>
</div>

<script src="jstree/jquery-3.6.0.min.js"></script>
<script src="jstree/jstree.min.js"></script>

<script>
	\$("#cancel").click(function() {
		window.close();
	});

	\$("#confirm").click(function() {
		let list = \$('#jstree').jstree(true).get_selected(true).map(n => n.original.fullpath).sort().reduce((a, v) => (a + '\\n' + v));
		\$(top.ifield).val(list);
		window.close();
	});

	\$(function () {
		\$('#jstree').jstree({
			'plugins' : [ 'checkbox' ],
			'core' : {
				'animation': 100,
				'worker' : false,
				'force_text': true,
				'data' : {
					'url' : function (node) {
						const r = [];
						r.push('fmt='    + 'json');
						r.push('job='    + encodeURIComponent('$in{'job'}'));
						r.push('volume=' + encodeURIComponent('$in{'volume'}'));
						r.push('dir='    + ((node.id == '#') ? encodeURIComponent('$shortest') : encodeURIComponent(node.original.fullpath)));
						return 'list.cgi?' + r.join('&');
					}
				}
			}
		});
	});
</script>

</body>
</html>
EOF
