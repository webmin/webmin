#!/usr/local/bin/perl
# Display all Webmin modules visible to the current user

$theme_index_page = 1;
require './web-lib.pl';
&ReadParse();
&init_config();
$hostname = &get_display_hostname();
$ver = &get_webmin_version();
&get_miniserv_config(\%miniserv);
if ($gconfig{'real_os_type'}) {
	if ($gconfig{'os_version'} eq "*") {
		$ostr = $gconfig{'real_os_type'};
		}
	else {
		$ostr = "$gconfig{'real_os_type'} $gconfig{'real_os_version'}";
		}
	}
else {
	$ostr = "$gconfig{'os_type'} $gconfig{'os_version'}";
	}
%access = &get_module_acl();

# Build a list of all modules
@modules = &get_visible_module_infos();

if (!defined($in{'cat'})) {
	# Maybe redirect to some module after login
	local $goto = &get_goto_module(\@modules);
	if ($goto) {
		&redirect($goto->{'dir'}.'/');
		exit;
		}
	}

@args = ( $gconfig{'nohostname'} ? $text{'main_title2'} :
	    &text('main_title', $ver, $hostname, $ostr), "");
&header(@args, undef, undef, 1, 1);

print $text{'main_header'};

if (!@modules) {
	# use has no modules!
	print "<p><b>$text{'main_none'}</b><p>\n";
	}
elsif ($gconfig{"notabs_${base_remote_user}"} == 2 ||
    $gconfig{"notabs_${base_remote_user}"} == 0 && $gconfig{'notabs'}) {
	# Generate main menu with all modules on one page
	print "<center><table cellpadding=5>\n";
	$pos = 0;
	$cols = $gconfig{'nocols'} ? $gconfig{'nocols'} : 4;
	$per = 100.0 / $cols;
	foreach $m (@modules) {
		local $idx = $m->{'index_link'};
		push(@links, "$gconfig{'webprefix'}/$m->{'dir'}/$idx");
		push(@titles, $m->{'desc'});
		push(@icons, "$m->{'dir'}/images/icon.gif");
		}
	&icons_table(\@links, \@titles, \@icons);
	}
else {
	# Display modules under current tab
	&ReadParse();
	%cats = &list_categories(\@modules);
	@cats = sort { $b cmp $a } keys %cats;
	$cats = @cats;
	$per = $cats ? 100.0 / $cats : 100;
	if (!defined($in{'cat'})) {
		# Use default category
		if (defined($gconfig{'deftab'}) &&
		    &indexof($gconfig{'deftab'}, @cats) >= 0) {
			$in{'cat'} = $gconfig{'deftab'};
			}
		else {
			$in{'cat'} = $cats[0];
			}
		}
	elsif (!$cats{$in{'cat'}}) {
		$in{'cat'} = "";
		}

	# Display the modules in this category
	$pos = 0;
	$cols = $gconfig{'nocols'} ? $gconfig{'nocols'} : 4;
	$per = 100.0 / $cols;
	foreach $m (@modules) {
		next if ($m->{'category'} ne $in{'cat'});
		local $idx = $m->{'index_link'};
		push(@links, "$gconfig{'webprefix'}/$m->{'dir'}/$idx");
		push(@titles, $m->{'desc'});
		push(@icons, "$m->{'dir'}/images/icon.gif");
		}
	&icons_table(\@links, \@titles, \@icons);
	}

print $text{'main_footer'};
&footer();

