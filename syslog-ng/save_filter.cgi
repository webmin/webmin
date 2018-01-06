#!/usr/local/bin/perl
# Create, update or delete a log filter

require './syslog-ng-lib.pl';
&ReadParse();
&error_setup($text{'filter_err'});

# Get the old filter
$conf = &get_config();
if (!$in{'new'}) {
	@filters = &find("filter", $conf);
	($filter) = grep { $_->{'value'} eq $in{'old'} } @filters;
	$filter || &error($text{'filter_egone'});
	$old = $filter;
	}
else {
	$filter = { 'name' => 'filter',
		  'type' => 1,
		  'members' => [ ] };
	}

&lock_all_files($conf);
if ($in{'delete'}) {
	# Just delete it!
	&check_dependencies('filter', $in{'old'}) &&
	    &error(&text('fdelete_eused', $in{'old'}));
	&save_directive($conf, undef, $filter, undef, 0);
	}
else {
	# Validate inputs, and update object
	$in{'name'} =~ /^[a-z0-9_]+$/i || &error($text{'filter_ename'});
	if ($in{'new'} || $in{'old'} ne $in{'name'}) {
		($clash) = grep { $_->{'value'} eq $in{'name'} } @filters;
		$clash && &error($text{'filter_eclash'});
		}
	$filter->{'values'} = [ $in{'name'} ];

	# Clear out current values
	$filter->{'members'} = [ ];

	if ($in{'mode'} == 0) {
		if ($in{'priority'}) {
			# Add selected priorities
			@pris = split(/\0/, $in{'pri'});
			@pris || &error($text{'filter_epris'});
			@pris = map { (",", $_) } @pris;
			shift(@pris);	# remove first ,
			push(@{$filter->{'members'}}, "and",
			     { 'name' => 'priority',
			       'type' => 0,
			       'values' => \@pris });
			}

		if ($in{'facility'}) {
			# Add selected facilities
			@facs = split(/\0/, $in{'fac'});
			@facs || &error($text{'filter_efacs'});
			@facs = map { (",", $_) } @facs;
			shift(@facs);	# remove first ,
			push(@{$filter->{'members'}}, "and",
			     { 'name' => 'facility',
			       'type' => 0,
			       'values' => \@facs });
			}

		if ($in{'program'}) {
			$in{'prog'} =~ /^\S+$/ || &error($text{'filter_eprog'});
			push(@{$filter->{'members'}}, "and",
			     { 'name' => 'program',
			       'type' => 0,
			       'values' => [ $in{'prog'} ] });
			}

		if ($in{'match'}) {
			$in{'re'} =~ /\S/ || &error($text{'filter_ematch'});
			push(@{$filter->{'members'}}, "and",
			     { 'name' => 'match',
			       'type' => 0,
			       'values' => [ $in{'re'} ] });
			}

		if ($in{'host'}) {
			$in{'hn'} =~ /^\S+$/ || &error($text{'filter_ehost'});
			push(@{$filter->{'members'}}, "and",
			     { 'name' => 'host',
			       'type' => 0,
			       'values' => [ $in{'hn'} ] });
			}

		if ($in{'netmask'}) {
		        &check_ipaddress($in{'net'}) ||
			      &error($text{'filter_enet'});
		        &check_ipaddress($in{'mask'}) ||
			      &error($text{'filter_emask'});
			push(@{$filter->{'members'}}, "and",
			     { 'name' => 'netmask',
			       'type' => 0,
			       'values' => [ $in{'net'}."/".$in{'mask'} ] });
			}

		if (@{$filter->{'members'}}) {
			# Remove first 'and'
			shift(@{$filter->{'members'}});
			}
		else {
			&error($text{'filter_enone'});
			}
		}

	else {
		# Parse boolean expression (in a temp file), and add to values
		$temp = &transname();
		&open_tempfile(TEMP, ">$temp", 0, 1);
		&print_tempfile(TEMP, "filter xxx {\n");
		&print_tempfile(TEMP, $in{'bool'},"\n");
		&print_tempfile(TEMP, "};\n");
		&close_tempfile(TEMP);
		eval {
		  $main::error_must_die = 1;
		  ($tfilter) = &read_config_file($temp);
		  };
		$@ && &error($text{'filter_ebool'});
		unlink($temp);
		$filter->{'members'} = $tfilter->{'members'};
		}
	
	# Actually update the object
	&save_directive($conf, undef, $old, $filter, 0);

	# Update dependent log targets
	if (!$in{'new'}) {
		&rename_dependencies('filter', $in{'old'}, $in{'name'});
		}
	}

&unlock_all_files();
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'filter', $in{'old'} || $in{'name'});
&redirect("list_filters.cgi");

