#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save, modify, delete a map for Postfix


require './postfix-lib.pl';

&ReadParse();


#     &ui_print_header(undef, $text{'aliases_title'}, "");

&error_setup($text{'map_save_err'});


my $maps = &get_maps($in{'map_name'});
my $add = 1; my %map;
## added to split main_parameter:sub_parameter
my ($mainparm,$subparm)=split /:/,$in{'map_name'};

foreach $trans (@{$maps})
{
    if ($trans->{'number'} == $in{'num'}) { $add = 0; %map = %{$trans}; }
}

my @maps_files = &get_maps_files(&get_current_value($in{'map_name'}));
if ($add) {
	# Last file must editable
	!@maps_files ||
	    &is_under_directory($access{'dir'}, $maps_files[$#maps_files]) ||
	        &error(&text('mapping_ecannot', $access{'dir'}));
} else {
	# Map must be in an editable file
	!$map{'map_file'} ||
	    &is_under_directory($access{'dir'}, $map{'map_file'}) ||
		&error(&text('mapping_ecannot', $access{'dir'}));
}

defined($maps_files[0]) || &error($text{'mapps_no_map_file'});
&lock_alias_files(\@maps_files);

if (!$in{'delete'}) {
	# Validate inputs
	##$nfunc = "parse_name_".$in{'map_name'};
	## modified to capture subparameters
	$nfunc="parse_name_"; $nfunc.=($subparm)? $subparm : $mainparm;
	if (defined(&$nfunc)) {
		$in{'name'} = &$nfunc(\%map, \%in);
		}
	else {
		$in{'name'} =~ /^\S+$/ || &error($text{'map_noname'});
		}
	##$vfunc = "parse_value_".$in{'map_name'};
	## modified to capture subparameters
	$vfunc="parse_value_"; $vfunc.=($subparm)? $subparm : $mainparm;
	if (defined(&$vfunc)) {
		$in{'value'} = &$vfunc(\%map, \%in);
		}
	}

if ($in{'delete'})
{
    if ($add == 1)
    {
	$whatfailed = "";
	&error(&text('map_delete_failed', $text{'map_delete_create'}));
    }
    &delete_mapping($in{'map_name'}, \%map);
    $logmap = \%map;
    $action = "delete";
}
elsif ($add == 0)
{
    # modify an existing map
    local %newmap = ( 'name' => $in{'name'},
		      'value' => $in{'value'},
		      'cmt' => $in{'cmt'} );
    &modify_mapping($in{'map_name'}, \%map, \%newmap);
    $logmap = \%newmap;
    $action = "modify";
}
else
{
    # add a new map -- much more easy! :-)
    local %newmap = ( 'name' => $in{'name'},
		      'value' => $in{'value'},
		      'cmt' => $in{'cmt'} );
    &create_mapping($in{'map_name'}, \%newmap);
    $logmap = \%newmap;
    $action = "create";
}
&unlock_alias_files(\@maps_files);

# re-creates database
&regenerate_map_table($in{'map_name'});
$err = &reload_postfix();
&error($err) if ($err);

&webmin_log($action, $in{'map_name'}, $logmap->{'name'}, $logmap);

&redirect_to_map_list($in{'map_name'});

