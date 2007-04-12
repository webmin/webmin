#!/usr/local/bin/perl
# save_perm.cgi
# Save permission options

require './wuftpd-lib.pl';
&error_setup($text{'perm_err'});
&ReadParse();
&lock_file($config{'ftpaccess'});
$conf = &get_ftpaccess();
@class = &find_value("class", $conf);

# Save chmod, delete, etc .. options
for($i=0; defined($type = $in{"type_$i"}); $i++) {
	next if (!$type);
	local @users = split(/\0/, $in{"users_$i"});
	local @classes = map { "class=$_" } split(/\0/, $in{"classes_$i"});
	@classes = () if (scalar(@classes) == scalar(@class));
	push(@$type, { 'name' => $type,
		       'values' => [ $in{"can_$i"},
				     join(",", @users, @classes) ] } );
	}
@permtypes = ( 'chmod', 'delete', 'overwrite', 'rename', 'umask' );
foreach $t (@permtypes) {
	&save_directive($conf, $t, \@$t);
	}

# Save path-filter options
for($i=0; defined($char = $in{"char_$i"}); $i++) {
	next if (!$char);
	$char =~ /^\S+$/ || &error(&text('perm_echar', $char));
	$in{"types_$i"} || &error($text{'perm_etypes'});
	$in{"types_$i"} =~ s/\0/,/g;
	-r $in{"mesg_$i"} || &error(&text('perm_emesg', $in{"mesg_$i"}));
	push(@filter, { 'name' => 'path-filter',
			'values' => [ $in{"types_$i"}, $in{"mesg_$i"},
				      $char, split(/\s+/, $in{"regexp_$i"})
				    ] } );
	}
&save_directive($conf, 'path-filter', \@filter);

&flush_file_lines();
&unlock_file($config{'ftpaccess'});
&webmin_log("perm", undef, undef, \%in);
&redirect("");

