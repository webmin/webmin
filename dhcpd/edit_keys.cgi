#!/usr/bin/perl
# $Id: edit_keys.cgi,v 1.2 2005/04/16 14:30:21 jfranken Exp $
# File added 2005-04-15 by Johannes Franken <jfranken@jfranken.de>
# Distributed under the terms of the GNU General Public License, v2 or later
#
# * Display TSIG keys for updates to DNS servers
#

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
$conf = &get_config();
@keys = ( &find("key", $conf), { } );

# check acls
# %access = &get_module_acl();
# &error_setup($text{'eacl_aviol'});
# &error("$text{'eacl_np'} $text{'eacl_pss'}") if !&can('r',\%access,$sub);

if ($in{'new'}) {
	&ui_print_header($desc, $text{'keys_create'}, "");
	}
else {
	&ui_print_header($desc, $text{'keys_edit'}, "");
	$key = $sub->{'members'}->[$in{'idx'}];
	}

print "<form action=save_keys.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'keys_id'}</b></td> ",
      "<td><b>$text{'keys_alg'}</b></td> ",
      "<td><b>$text{'keys_secret'}</b></td> </tr>\n";
for($i=0; $i<@keys; $i++) {
	$k = $keys[$i];
	print "<tr $cb>\n";
	printf "<td><input name=id_$i size=15 value='%s'></td>\n",
		$k->{'value'};

	@algs = ( "hmac-md5" );
	$alg = &find_value("algorithm", $k->{'members'});
	print "<td><select name=alg_$i>\n";
	local $found;
	foreach $a (@algs) {
		printf "<option %s>%s</option>\n", $alg eq $a ? "selected" : "", $a;
		$found++ if ($alg eq $a);
		}
	print "<option selected>$alg</option>\n" if (!$found && $alg);
	print "</select></td>\n";

	printf "<td><input name=secret_$i size=64 value='%s'></td> </tr>\n",
		&find_value("secret", $k->{'members'});
	}
print "</table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

