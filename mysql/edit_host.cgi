#!/usr/local/bin/perl
# edit_host.cgi
# Edit or create a host table record

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_ecannot'});

if ($in{'new'}) {
	&ui_print_header(undef, $text{'host_title1'}, "");
	}
else {
	$d = &execute_sql_safe($master_db, "select * from host order by host");
	$u = $d->{'data'}->[$in{'idx'}];
	$access{'perms'} == 1 || &can_edit_db($u->[1]) ||
		&error($text{'perms_edb'});
	&ui_print_header(undef, $text{'host_title2'}, "");
	}

print &ui_form_start("save_host.cgi");
if ($in{'new'}) {
	print &ui_hidden("new", 1);
	}
else {
	print &ui_hidden("oldhost", $u->[0]);
	print &ui_hidden("olddb", $u->[1]);
	}
print &ui_table_start($text{'host_header'}, undef, 2);
%fieldmap = map { $_->{'field'}, $_->{'index'} }
		&table_structure($master_db, "host");

# Database name
print &ui_table_row($text{'host_db'}, &select_db($u->[1]));

# Hostname pattern
print &ui_table_row($text{'host_host'},
	&ui_opt_textbox("host", $u->[0] eq '%' ? '' : $u->[0], 40,
			$text{'host_any'}));

# Host's permissions
foreach my $f (&priv_fields('host')) {
	push(@opts, $f);
	push(@sel, $f->[0]) if ($u->[$fieldmap{$f->[0]}] eq 'Y');
	}
print &ui_table_row($text{'host_perms'},
	&ui_select("perms", \@sel, \@opts, 10, 1, 1));

print &ui_table_end();
print &ui_form_end([ $in{'new'} ? ( [ undef, $text{'create'} ] )
				: ( [ undef, $text{'save'} ],
				    [ 'delete', $text{'delete'} ] ) ]);

&ui_print_footer('list_hosts.cgi', $text{'hosts_return'},
	"", $text{'index_return'});

