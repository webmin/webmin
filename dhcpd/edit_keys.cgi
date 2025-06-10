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

print &ui_form_start("save_keys.cgi", "post");
print &ui_columns_start([$text{'keys_id'}, $text{'keys_alg'}, $text{'keys_secret'}]);

for($i=0; $i<@keys; $i++) {
	$k = $keys[$i];
    my @column_row;
    push(@column_row, &ui_textbox("id_".$i, $k->{'value'}, 15) );

	my @algs = ( "hmac-md5" );
	$alg = &find_value("algorithm", $k->{'members'});
    my @algs_sel;
    
	my $found;
	foreach $a (@algs) {
        push(@algs_sel, [$a, $a, ($alg eq $a ? "selected" : "") ] );
		$found++ if ($alg eq $a);
		}
    push(@algs_sel,[$alg, $alg, ""]) if (!$found && $alg);
    push(@column_row, &ui_select("alg_".$i, undef, \@algs_sel, 1) );
    push(@column_row, &ui_textbox("secret_".$i, &find_value("secret", $k->{'members'}), 64) );
    print &ui_columns_row(\@column_row);
	}
print &ui_columns_end();
print &ui_submit($text{'save'});
print &ui_form_end(undef,undef,1);

&ui_print_footer("", $text{'index_return'});

