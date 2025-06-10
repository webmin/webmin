#!/usr/local/bin/perl
# Actually creates a new zone

require './zones-lib.pl';
do 'forms-lib.pl';
&ReadParse();
&error_setup($text{'create_err'});
&foreign_require("time", "time-lib.pl");
&foreign_require("useradmin", "user-lib.pl");

# Validate inputs
$form = &get_create_form(\%in);
$form->validate_redirect("create_form.cgi");
$path = $form->get_value("path") || "$config{'base_dir'}/$in{'name'}";
mkdir($config{'base_dir'}, 0700);
-d $path && $form->validate_redirect("create_form.cgi",
		[ [ "path", &text('create_epath2', $path) ] ]);
@pkgs = split(/[\r\n]+/, $form->get_value("pkgs"));
if ($in{'webmin'}) {
	push(@pkgs, $root_directory);
	}
if ($in{'cfg'}) {
	# Validate initial configuration fields, and create sysidcfg
	@sysidcfg = ( );
	if ($in{'root_def'}) {
		($root) = grep { $_->{'user'} eq 'root' }
			  &useradmin::list_users();
		$root || &error($text{'create_eroot'});
		push(@sysidcfg, [ 'root_password' => $root->{'pass'} ]);
		}
	else {
		push(@sysidcfg, [ 'root_password' =>
				&useradmin::encrypt_password(
					$form->get_value("root")) ]);
		}
	if ($in{'timezone_def'}) {
		push(@sysidcfg, [ 'timezone' =>
				   &time::get_current_timezone() ]);
		}
	else {
		push(@sysidcfg, [ 'timezone' => $form->get_value('timezone') ]);
		}
	if ($in{'locale_def'}) {
		push(@sysidcfg, [ 'system_locale' => &get_global_locale() ]);
		}
	else {
		push(@sysidcfg, [ 'system_locale' => $form->get_value('locale') ]);
		}
	if ($in{'terminal_def'}) {
		push(@sysidcfg, [ 'terminal' => 'vt100' ]);
		}
	else {
		push(@sysidcfg, [ 'terminal' => $form->get_value('terminal') ]);
		}

	# Setup DNS or NIS resolution
	$ns = [ uc($form->get_value('resolv')) ];
	if ($form->get_value('resolv') ne 'none') {
		push(@$ns, [ 'domain_name' => $form->get_value("domain") ]);
		foreach $n (split(/\s+/, $in{'server'})) {
			$ip = &to_ipaddress($n);
			push(@$ns, [ 'name_server' => "$n($ip)" ]);
			}
		}
	push(@sysidcfg, [ 'name_service' => $ns ]);
	
	# Set the NFS4 Domain as dynamic so that
    # upon first boot we don't get asked
	push(@sysidcfg, ['nfs4_domain' => "dynamic"]);

	# Setup network interface config
	push(@sysidcfg, [ 'security_policy' => 'NONE' ]);
	if ($in{'hostname_def'}) {
		$hostname = $form->get_value("name");
		}
	else {
		$hostname = $form->get_value("hostname");
		}
	if ($in{'address_def'}) {
		push(@sysidcfg, [ 'network_interface' =>
			[ "none", [ 'hostname' => $hostname ] ] ]);
		}
	else {
		&to_ipaddress($hostname) ||
			$form->validate_redirect("create_form.cgi",
			    [ [ "hostname", $text{'create_eresolvname'} ] ]);
		push(@sysidcfg, [ 'network_interface' =>
			[ "primary", [ 'hostname' => $hostname ],
				     [ 'ip_address' => $in{'address'} ],
			    $in{'router_def'} ? ( ) : (
				[ 'default_route' => $in{'router'} ] ) ] ]);
		}
	}

$p = new WebminUI::Page(undef, $text{'create_title'});

$d1 = new WebminUI::DynamicHTML(\&execute_create, undef, $text{'create_adding'});
$p->add_form($d1);
sub execute_create
{
$zinfo = &create_zone($form->get_value("name"), $path);
$p->add_message_after($d1, $text{'create_done'});
}

if (!$in{'address_def'}) {
	# Set initial network address
	$d2 = new WebminUI::DynamicHTML(\&execute_address, undef, $text{'create_addingnet'});
	$p->add_form($d2);
	  sub execute_address
	  {
	  $net = { 'keytype' => 'net',
		 'address' => $in{'address'},
		 'physical' => $in{'physical'} };
	  &create_zone_object($zinfo, $net);
	  $p->add_message_after($d2, $text{'create_done'});
	  }
	}

# Add or remove extra package directories
# add for sparse root zone and remove for whole root zone
if ($in{'inherit'} eq '0' ) {
	$d3 = new WebminUI::DynamicHTML(\&remove_pkgs, undef, $text{'create_removingpkgs'});
		$p->add_form($d3);
	sub remove_pkgs
	{
		$pkg = { 'keytype' => 'inherit-pkg-dir' };
		&delete_zone_object($zinfo,$pkg);
		$p->add_message_after($d3, $text{'create_done'});
	}
}
  else {
	if (@pkgs) {
		$d3 = new WebminUI::DynamicHTML(\&execute_pkgs, undef, $text{'create_addingpkgs'});
		$p->add_form($d3);
		  sub execute_pkgs
		  {
		  foreach $p (@pkgs) {
			$pkg = { 'keytype' => 'inherit-pkg-dir',
				 'dir' => $p };
			&create_zone_object($zinfo, $pkg);
			}
		  $p->add_message_after($d3, $text{'create_done'});
		  }
		}
	}

#set the brand
if ($in{'brand'}) {
	$d4 = new WebminUI::DynamicHTML(\&create_brand,undef, $text{'create_brandmsg'});
	$p->add_form($d4);
	
	sub create_brand
	{
		&set_zone_variable($zinfo,"brand",$form->get_value("brand"));
		$p->add_message_after($d4, $text{'create_done'});
	}
}

if ($in{'install'}) {
	# Install software
	$d5 = new WebminUI::DynamicText(\&execute_install);
	$p->add_form($d5);
	$d5->set_message($text{'create_installing'});
	$d5->set_wait(1);
	  sub execute_install
	  {
	  local $ok = &callback_zone_command($zinfo, "install",
				\&WebminUI::DynamicText::add_line, [ $d5 ]);
	  if ($ok) {
		$p->add_message_after($d5, $text{'create_done'});
		}
	  else {
		$p->add_error_after($d5, $text{'create_failed'});
		}

	  if (@sysidcfg) {
		# Save the sysidcfg file
		&save_sysidcfg(\@sysidcfg, "$path/root/etc/sysidcfg");
		}
		if (-e "$path/root/etc/.UNCONFIGURED") {
		# If the file .UNCONFIGURED is there remove it
			&system_logged("rm -f $path/root/etc/.UNCONFIGUREED");
		}
	  &config_zone_nfs($zinfo);
	  &run_zone_command($zinfo, "boot");
	  }
	}
else {
	# Save sysidcfg for later install
	if (@sysidcfg) {
		&save_sysidcfg(\@sysidcfg, &zone_sysidcfg_file($in{'name'}));
		}
	}

if ($in{'install'} && $in{'webmin'}) {
	# Create a Webmin setup script and run it
	$d6 = new WebminUI::DynamicText(\&execute_webmin);
	$p->add_form($d6);
	$d6->set_message($text{'create_webmining'});
	$d6->set_wait(1);

	sub execute_webmin
	{
	$script = &get_zone_root($zinfo)."/tmp/install-webmin";
	$err = &create_webmin_install_script($zinfo, $script);
	if ($err) {
		$p->add_error_after($d6, &text('created_wfailed', $err));
		}
	else {
		$ex = &run_in_zone_callback($zinfo, "/tmp/install-webmin",
				\&WebminUI::DynamicText::add_line, [ $d ]);
		if (!$ex) {
			$p->add_message($text{'create_done'});
			&post_webmin_install($zinfo);
			}
		else {
			$p->add_error($text{'create_failed'});
			}
		}
	}
	}

$p->add_footer("index.cgi", $text{'index_return'});
$p->print();
&webmin_log("create", "zone", $in{'name'});

