use WebminUI::All;
use Socket;

# get_zone_form(&in, &zinfo)
# Returns a form for editing a zone
sub get_zone_form
{
local ($in, $zinfo) = @_;
local $form = new WebminUI::Form("save_zone.cgi");
$form->set_input($in);
$form->add_hidden("zone", $zinfo->{'name'});
local $section = new WebminUI::Section($text{'edit_common'}, 4, undef, "100%");
$form->add_section($section);

$section->add_row($text{'edit_name'}, "<tt>$in{'zone'}</tt>");
$section->add_row($text{'edit_status'}, &nice_status($zinfo->{'status'}));
$section->add_row($text{'edit_zonepath'}, "<tt>$zinfo->{'zonepath'}</tt>");
local $auto = new WebminUI::Select("autoboot", $zinfo->{'autoboot'},
				 [ [ "true", $text{'yes'} ],
                                   [ "false", $text{'no'} ] ]);
$section->add_input($text{'edit_autoboot'}, $auto);
local $pool = &pool_object("pool", $zinfo->{'pool'});
$section->add_input($text{'edit_pool'}, $pool);
$section->add_row($text{'edit_brand'}, "$zinfo->{'brand'}");

local @actions = &zone_status_actions($zinfo, 1);
$form->add_button(new WebminUI::Submit($text{'save'}, "save"));
$form->add_button_spacer();
foreach my $a (@actions) {
	$form->add_button(new WebminUI::Submit($a->[1], $a->[0]));
	}
$form->add_button_spacer() if (@actions);
$form->add_button(new WebminUI::Submit($text{'edit_delete'}, "delete"));
return $form;
}

sub pool_object
{
local ($name, $value) = @_;
local $rv = new WebminUI::OptTextbox($name, $value, 10, $text{'pool_none'});
$rv->set_validation_regexp('^\S+$', $text{'save_epool'});
return $rv;
}

# get_confirm_page(&in, type, &zinfo, from-list)
sub get_confirm_page
{
local ($in, $action, $zinfo, $list) = @_;
local $p = new WebminUI::ConfirmPage(&zone_title($zinfo->{'name'}),
		   $text{$action.'_title'},
		   &text($action.'_rusure', "<tt>$zinfo->{'name'}</tt>"),
		   "save_zone.cgi", $in, $text{'edit_'.$action}, $text{'ui_cancel'});
if ($list) {
	$p->add_footer("index.cgi", $text{'index_return'});
	}
else {
	$p->add_footer("edit_zone.cgi?zone=$zinfo->{'name'}",
		       $text{'edit_return'});
	}
return $p;
}

# get_execute_page(action, &zinfo, from-list, action-args)
sub get_execute_page
{
local ($action, $zinfo, $list, $args) = @_;
local $p = new WebminUI::Page(&zone_title($zinfo->{'name'}),
			    $text{$action.'_title'});
local $d = new WebminUI::DynamicWait(\&execute_action, [ $action, $zinfo, $args ]);
$p->add_form($d);
$d->set_message($text{$action.'_doing'});
$d->set_wait(1);
if ($list || $action eq "delete") {
	$p->add_footer("index.cgi", $text{'index_return'});
	}
else {
	$p->add_footer("edit_zone.cgi?zone=$zinfo->{'name'}",
		       $text{'edit_return'});
	}
return $p;
}

sub execute_action
{
my ($d, $action, $zinfo, $args) = @_;
sleep(1);
local ($out, $ex);
if ($action eq "delete") {
	# Halt and un-install before deleting
	if ($zinfo->{'status'} ne 'configured') {
		if ($zinfo->{'status'} ne 'installed' &&
		    $zinfo->{'status'} ne 'incomplete') {
			($out, $ex) = &run_zone_command($zinfo, "halt");
			}
		if (!$ex) {
			($out, $ex) = &run_zone_command($zinfo, "uninstall -F");
			}
		}
	if (!$ex) {
		&delete_zone($zinfo);
		}
	}
else {
	# Just run zoneadm to execute action
	($out, $ex) = &run_zone_command($zinfo,
				      $action.($args ? " $args" : ""), 1);
	}
$d->stop();
if ($ex) {
	$p->add_error($text{'reboot_failed'}, $out);
	}
else {
	$p->add_message($text{'reboot_ok'});
	if ($action eq "delete") {
		unlink(&zone_sysidcfg_file($zinfo->{'name'}));
		}
	&webmin_log($action, "zone", $zinfo->{'name'});
	}
}

# get_net_form(&in, &zinfo, &net)
sub get_net_form
{
local ($in, $zinfo, $net) = @_;
local ($new, $active, $address, $netmask);
local $form = new WebminUI::Form("save_net.cgi", "post");
$form->add_hidden("zone", $zinfo->{'name'});
if ($net->{'address'}) {
	$active = &get_active_interface($net);
	($address, $netmask) = &get_address_netmask($net, undef);
	$form->add_hidden("old", $net->{'address'});
	}
else {
	$net = { 'physical' => &get_default_physical() };
	$new = 1;
	$form->add_hidden("new", 1);
	}
$form->set_input($in);
local $section = new WebminUI::Section($text{'net_header'}, 2);
$form->add_section($section);

local $ainput = new WebminUI::Textbox("address", $address, 20);
$ainput->set_mandatory(1);
$ainput->set_validation_func(\&validate_address);
$section->add_input($text{'net_address'}, $ainput);

local $pinput = &physical_object("physical", $net->{'physical'});
$section->add_input($text{'net_physical'}, $pinput);

local $ninput = new WebminUI::OptTextbox("netmask", $netmask, 20,
				       $text{'default'});
$ninput->set_validation_func(\&validate_netmask);
$section->add_input($text{'net_netmask'}, $ninput);

if ($active) {
	$section->add_row($text{'net_broadcast'},
                          "<tt>$active->{'broadcast'}</tt>");
	}

if ($new) {
	$form->add_button(new WebminUI::Submit($text{'create'}, "create"));
	}
else {
	$form->add_button(new WebminUI::Submit($text{'save'}, "save"));
	$form->add_button(new WebminUI::Submit($text{'delete'}, "delete"));
	}
return $form;
}

# physical_object(name, value)
# Returns an input for selecting a real interface
sub physical_object
{
local ($name, $value) = @_;
return new WebminUI::Select($name, $value,
       [ map { [ $_->{'name'} ] } grep { $_->{'virtual'} eq '' }
	     &net::active_interfaces() ], 0, $value ? 1 : 0);
}

sub validate_address
{
return &check_ipaddress($_[0]) ? undef : $text{'net_eaddress'};
}

sub validate_netmask
{
return &check_ipaddress($_[0]) ? undef : $text{'net_enetmask'};
}

# get_pkg_form(&in, &zinfo, &pkg)
sub get_pkg_form
{
local ($in, $zinfo, $pkg) = @_;
local ($new);
local $form = new WebminUI::Form("save_pkg.cgi", "post");
$form->set_input($in);
$form->add_hidden("zone", $zinfo->{'name'});
if ($pkg->{'dir'}) {
	$form->add_hidden("old", $pkg->{'dir'});
	}
else {
	$new = 1;
	$form->add_hidden("new", 1);
	}
local $section = new WebminUI::Section($text{'pkg_header'}, 2);
$form->add_section($section);

local $dinput = new WebminUI::File("dir", $pkg->{'dir'}, 50, 1);
$dinput->set_mandatory(1);
$dinput->set_validation_func(\&validate_dir);
$section->add_input($text{'pkg_dir'}, $dinput);

if ($new) {
	$form->add_button(new WebminUI::Submit($text{'create'}, "create"));
	}
else {
	$form->add_button(new WebminUI::Submit($text{'save'}, "save"));
	$form->add_button(new WebminUI::Submit($text{'delete'}, "delete"));
	}
return $form;
}

sub validate_dir
{
return -d $_[0] ? undef : $text{'pkg_edir'};
}

# get_attr_form(&in, &zinfo, &attr)
sub get_attr_form
{
local ($in, $zinfo, $pkg) = @_;
local ($new);
local $form = new WebminUI::Form("save_attr.cgi", "post");
$form->set_input($in);
$form->add_hidden("zone", $zinfo->{'name'});
if ($attr->{'name'}) {
	$form->add_hidden("old", $attr->{'name'});
	}
else {
	$new = 1;
	$form->add_hidden("new", 1);
	}
local $section = new WebminUI::Section($text{'attr_header'}, 2);
$form->add_section($section);

local $ninput = new WebminUI::Textbox("name", $attr->{'name'}, 30);
$ninput->set_mandatory(1);
$ninput->set_validation_regexp('^\S+$', $text{'attr_ename'});
$section->add_input($text{'attr_name'}, $ninput);

local $tinput = new WebminUI::Select("type", $attr->{'type'} || "string",
		       [ map { [ $_, $text{'attr_'.$_} ] }
			     &list_attr_types() ], 0, 1);
$section->add_input($text{'attr_type'}, $tinput);

local $vinput = new WebminUI::Textbox("value", $attr->{'value'}, 30);
$vinput->set_validation_func(\&validate_value);
$vinput->set_mandatory(1);
$section->add_input($text{'attr_value'}, $vinput);

if ($new) {
	$form->add_button(new WebminUI::Submit($text{'create'}, "create"));
	}
else {
	$form->add_button(new WebminUI::Submit($text{'save'}, "save"));
	$form->add_button(new WebminUI::Submit($text{'delete'}, "delete"));
	}
return $form;
}

sub validate_value
{
local ($value, $name, $form) = @_;
if ($form->get_value("type") eq 'int') {
	$value =~ /^\-?\d+$/ || return $text{'attr_eint'};
	}
elsif ($form->get_value("type") eq 'uint') {
	$value =~ /^\d+$/ || return $text{'attr_euint'};
	}
elsif ($form->get_value("type") eq 'boolean') {
	$value eq "true" || $value eq "false" ||
		return $text{'attr_uboolean'};
	}
return undef;
}

# get_fs_form(in, &zinfo, &fs, type)
sub get_fs_form
{
local ($in, $zinfo, $fs, $type) = @_;
local ($new, $mount);
local $form = new WebminUI::Form("save_fs.cgi", "post");
$form->set_input($in);
$form->add_hidden("zone", $zinfo->{'name'});
if ($fs->{'dir'}) {
	$form->add_hidden("old", $fs->{'dir'});
	$mount = &get_active_mount($zinfo, $fs);
	}
else {
	$new = 1;
	$form->add_hidden("new", 1);
	$form->add_hidden("type", $type);
	}
local $section = new WebminUI::Section($text{'fs_header'}, 2);
$form->add_section($section);

$section->add_row($text{'fs_type'},
                  &mount::fstype_name($type)." (".uc($type).")");

if (!$new) {
	if ($mount) {
		($total, $free) = &mount::disk_space($mount->[2], $mount->[0]);
		$section->add_row($text{'fs_status'},
			$total ? &text('fs_mountedsp', &nice_size($total*1024),
						       &nice_size($free*1024)) :
			         $text{'fs_mounted'});
		}
	else {
		$section->add_row($text{'fs_status'}, $text{'fs_unmounted'});
		}
	}
else {
	$section->add_row($text{'fs_mount'},
		      &ui_yesno_radio("mount", $zinfo->{'status'} eq 'running' ?
					       1 : 0));
	}

local $dinput = new WebminUI::File("dir", $fs->{'dir'}, 50);
$dinput->set_mandatory(1);
$dinput->set_validation_func(\&validate_fsdir);
$section->add_input($text{'fs_dir'}, $dinput);

$main::ui_table_cols = 2;
if (&indexof($type, &mount::list_fstypes()) >= 0) {
	# A supported filesystem, which means we can show nice options
	local $shtml = 
	    "<table border width=100%><tr><td><table>".
	    &capture_function_output(\&mount::generate_location, $type,
				     $fs->{'special'}).
	    "</table></td></tr></table>";
	$section->add_row($text{'fs_special'}, $shtml);

	&mount::parse_options($type, $fs->{'options'});
	local $ohtml =
	    "<table border width=100%><tr><td><table>".
	    &capture_function_output(\&mount::generate_options, $type,
				     $new ? 1 : 0).
	    "</table></td></tr></table>";
	$section->add_row($text{'fs_options'}, $ohtml);
	}
else {
	# Un-supported, so show just text fields
	local $sinput = new WebminUI::Textbox("special", $fs->{'special'}, 40);
	$sinput->set_mandatory(1);
	$sinput->set_validation_func(\&validate_special);
	$section->add_input($text{'fs_special'}, $sinput);

	local $oinput = new WebminUI::Textbox("options", $fs->{'options'}, 40);
	$oinput->set_mandatory(1);
	$oinput->set_validation_func(\&validate_options);
	$section->add_input($text{'fs_options'}, $oinput);
	}

if ($new) {
	$form->add_button(new WebminUI::Submit($text{'create'}, "create"));
	}
else {
	$form->add_button(new WebminUI::Submit($text{'save'}, "save"));
	$form->add_button(new WebminUI::Submit($text{'delete'}, "delete"));
	}
return $form;
}

sub validate_fsdir
{
return $_[0] =~ /^\/\S/ ? undef : $text{'fs_edir'};
}

sub validate_special
{
return $_[0] =~ /\S/ ? undef : $text{'fs_especial'};
}

sub validate_options
{
return $_[0] =~ /^\S*$/ ? undef : $text{'fs_eoptions'};
}

# get_rctl_form(&in, &zinfo, &rctl)
sub get_rctl_form
{
local ($in, $zinfo, $rctl) = @_;
local ($new, $mount);
local $form = new WebminUI::Form("save_rctl.cgi", "post");
$form->set_input($in);
$form->add_hidden("zone", $zinfo->{'name'});
if ($rctl->{'name'}) {
	$form->add_hidden("old", $rctl->{'name'});
	}
else {
	$new = 1;
	$form->add_hidden("new", 1);
	}
local $section = new WebminUI::Section($text{'rctl_header'}, 2);
$form->add_section($section);

local $ninput = new WebminUI::Select("name", $rctl->{'name'},
                [ map { [ $_ ] } grep { /^zone\./ } &list_rctls() ],
                0, $in{'new'} ? 0 : 1);
$section->add_input($text{'rctl_name'}, $ninput);

local $table = new WebminUI::InputTable([ $text{'rctl_priv'},
				        $text{'rctl_limit'},
				        $text{'rctl_action'} ]);
$form->add_section($table);
local $pinput = new WebminUI::Select("priv", undef,
		   [ [ "", "&nbsp;" ],
		     [ "privileged", $text{'rctl_privileged'} ] ]);
local $linput = new WebminUI::Textbox("limit", undef, 20);
$linput->set_mandatory(1);
$linput->set_validation_func(\&validate_limit);
local $ainput = new WebminUI::Select("action", undef,
			   [ [ "none", $text{'rctl_none'} ],
			     [ "deny", $text{'rctl_deny'} ] ]);
$table->set_inputs([ $pinput, $linput, $ainput ]);
local @values = split(/\0/, $rctl->{'value'});
foreach my $v (@values, "") {
	($priv, $limit, $action) = &get_rctl_value($v);
	($actionn, $actionv) = split(/=/, $action);
	$table->add_values([ $priv, $limit, $actionn ]);
	}
$table->set_emptymsg("No RCTLs defined yet");
$table->set_all_sortable(0);
$table->set_control(0);

if ($new) {
	$form->add_button(new WebminUI::Submit($text{'create'}, "create"));
	}
else {
	$form->add_button(new WebminUI::Submit($text{'save'}, "save"));
	$form->add_button(new WebminUI::Submit($text{'delete'}, "delete"));
	}
return $form;
}

sub validate_limit
{
return $_[0] =~ /^\d+$/ ? undef : $text{'rctl_elimit'};
}

sub get_create_form
{
local ($in) = @_;
local $form = new WebminUI::Form("create_zone.cgi", "post");
$form->set_input($in);
local $section = new WebminUI::Section($text{'create_header'}, 2);
$form->add_section($section);
&foreign_require("time", "time-lib.pl");

local $name = new WebminUI::Textbox("name", undef, 20);
$name->set_mandatory(1);
$name->set_validation_func(\&validate_zone_name);
$section->add_input($text{'edit_name'}, $name);

local $path = new WebminUI::OptTextbox("path", undef, 30,
		&text('create_auto', $config{'base_dir'}),
		$text{'create_sel'});
$path->set_validation_func(\&validate_zone_path);
$section->add_input($text{'create_path'}, $path);

local $brand = new WebminUI::Select("brand",undef, [ &list_brands() ], 0, 0, $value ? 1 : 0);
$section->add_input($text{'create_brand'}, $brand);

local $address = new WebminUI::OptTextbox("address", undef, 20,
					$text{'create_noaddress'});
$address->set_validation_func(\&validate_address);
$section->add_input($text{'create_address'}, $address);

local $physical = &physical_object("physical", &get_default_physical());
$section->add_input($text{'net_physical'}, $physical);

local $install = new WebminUI::Radios("install", 0, [ [ 1, $text{'yes'} ],
						    [ 0, $text{'no'} ] ]);
$section->add_input($text{'create_install'}, $install);

local $webmin = new WebminUI::Radios("webmin", 0, [ [ 1, $text{'yes'} ],
						    [ 0, $text{'no'} ] ]);
$section->add_input($text{'create_webmin'}, $webmin);

local $inherit = new WebminUI::Radios("inherit", 1, [ [ 1, $text{'pkg_inherit_yes'} ],
						    [ 0, $text{'pkg_inherit_no'} ] ]);
$section->add_input($text{'pkg_inherit'}, $inherit);


local $pkgs = new WebminUI::Multiline("pkgs", undef, 5, 50);
$section->add_input($text{'create_pkgs'}, $pkgs);

$section->add_separator();

local $cfg = new WebminUI::Radios("cfg", 1, [ [ 1, $text{'create_cfgyes'} ],
                                          [ 0, $text{'create_cfgno'} ] ]);
$section->add_input($text{'create_cfg'}, $cfg);

local $hostname = new WebminUI::OptTextbox("hostname", undef, 20,
					 $text{'create_samehost'});
$hostname->set_validation_func(\&validate_zone_hostname);
$section->add_input($text{'create_hostname'}, $hostname);

local $root = new WebminUI::OptTextbox("root", undef, 20,
					 $text{'create_same'});
$section->add_input($text{'create_root'}, $root);

local $currtz = &time::get_current_timezone();
local $timezone = new WebminUI::OptTextbox("timezone", undef, 25,
					 &text('create_same2', $currtz));
$timezone->set_validation_func(\&validate_zone_timezone);
$section->add_input($text{'create_timezone'}, $timezone);

local $currlc = &get_global_locale();
local $locale = new WebminUI::OptTextbox("locale", undef, 25,
					 &text('create_same2', $currlc));
$locale->set_validation_func(\&validate_zone_locale);
$section->add_input($text{'create_locale'}, $locale);

local $terminal = new WebminUI::OptTextbox("terminal", undef, 25,
					 $text{'create_vt100'});
$terminal->set_validation_func(\&validate_zone_terminal);
$section->add_input($text{'create_terminal'}, $terminal);

local $dns = &net::get_dns_config();
local ($resolv) = grep { $_ ne "files" } split(/\s+/, $dns->{'order'});
$resolv ||= "none";
local $rinput = new WebminUI::Radios("resolv", $resolv,
				  [ [ "none", $text{'create_none'} ],
                                    [ "dns", $text{'create_dns'} ],
                                    [ "nis", $text{'create_nis'} ],
                                    [ "nis+", $text{'create_nis+'} ] ]);
$section->add_input($text{'create_name'}, $rinput);

local $domain = $resolv eq "dns" ? $dns->{'domain'}->[0] :
	  $resolv eq "nis" || $resolv eq "nis+" ? &net::get_domainname()
						: undef;
local $dinput = new WebminUI::Textbox("domain", $domain, 20);
$dinput->set_validation_func(\&validate_zone_domain);
$dinput->set_disable_code("form.resolv[0].checked");
$section->add_input($text{'create_domain'}, $dinput);

local (@servers, $server);
if ($resolv eq "dns") {
	@servers = map { &to_ipaddress($_) || &to_ip6address($_) || $_ }
			 @{$dns->{'nameserver'}};
	$server = join(" ", @servers);
	}
elsif ($resolv eq "nis" || $resolv eq "nis+") {
	$server = `ypwhich`;
	chop($server);
	}
local $server = new WebminUI::Textbox("server", $server, 40);
$server->set_validation_func(\&validate_zone_server);
$server->set_disable_code("form.resolv[0].checked");
$section->add_input($text{'create_server'}, $server);

local ($router) = &net::get_default_gateway();
if (!$router) {
	# Use active settings
	foreach my $r (&net::list_routes()) {
		$router = $r->{'gateway'} if ($r->{'dest'} eq '0.0.0.0');
		}
	}
local $rinput = new WebminUI::OptTextbox("router", $router, 20,
				       $text{'create_none'});
$rinput->set_validation_func(\&validate_zone_router);
$section->add_input($text{'create_router'}, $rinput);

$form->add_button(new WebminUI::Submit($text{'create_ok'}));
return $form;
}

sub validate_zone_name
{
return $text{'create_ename'} if ($_[0] !~ /^[a-z0-9\.\-\_]+$/i);
my ($clash) = grep { $_->{'name'} eq $in{'name'} } &list_zones();
return $text{'create_eclash'} if ($clash);
return undef;
}

sub validate_zone_path
{
return $_[0] =~ /^\// ? undef : $text{'create_epath'};
}

sub validate_zone_pkgs
{
my @pkgs = split(/[\r\n]+/, $in{'pkgs'});
foreach my $p (@pkgs) {
        $p =~ /^\/\S/ || return &text('create_epkg', $p);
        }
return undef;
}

sub validate_zone_hostname
{
return $_[0] =~ /^[a-z0-9\.\-\_]+$/ ? undef : $text{'create_ehostname'};
}

sub validate_zone_timezone
{
return $_[0] =~ /^\S+$/ ? undef : $text{'create_etimezone'};
}

sub validate_zone_locale
{
return $_[0] =~ /^\S+$/ ? undef : $text{'create_elocale'};
}

sub validate_zone_domain
{
return undef if ($_[2]->get_value("resolv") eq "none");
return $_[0] =~ /^[a-z0-9\.\-\_]+$/ ? undef : $text{'create_edomain'};
}

sub validate_zone_server
{
return undef if ($_[2]->get_value("resolv") eq "none");
local @servers = split(/\s+/, $in{'server'});
foreach my $n (@servers) {
	return &text('create_eserver', $n) if (!&to_ipaddress($n));
	}
return @servers ? undef : $text{'create_eservers'};
}

sub validate_zone_router
{
return &check_ipaddress($_[0]) ? undef : $text{'create_erouter'};
}

sub validate_zone_terminal
{
return $_[0] =~ /^\S+$/ ? undef : $text{'create_eterminal'};
}

