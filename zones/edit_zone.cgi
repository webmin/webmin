#!/usr/local/bin/perl
# Shows the details of one zone, with links to make changes

require './zones-lib.pl';
do 'forms-lib.pl';
&ReadParse();
$zinfo = &get_zone($in{'zone'});
$zinfo || &error($text{'edit_egone'});

$p = new WebminUI::Page(&zone_title($in{'zone'}), $text{'edit_title'}, "edit");

# Show general information
$gform = &get_zone_form(\%in, $zinfo);
$p->add_form($gform);

# Show network interfaces
$p->add_separator();
$nform = new WebminUI::Form();
$p->add_form($nform);
$nform->set_input(\%in);
$ntable = new WebminUI::Table([ $text{'edit_netaddress'},
                              $text{'edit_netname'},
                              $text{'edit_netmask'},
                              $text{'edit_netbroad'} ], "100%", "ntable");
$nform->add_section($ntable);
$ntable->set_heading($text{'edit_net'});
foreach $net (@{$zinfo->{'net'}}) {
	$active = &get_active_interface($zinfo, $net);
	($address, $netmask) = &get_address_netmask($net, $active);
	$ntable->add_row([
		&ui_link("edit_net.cgi?zone=$in{'zone'}&old=$net->{'address'}",$address),
		$active->{'fullname'} || $text{'edit_netdown'},
		$netmask,
		$active->{'broadcast'} ]);
	}
$ntable->set_emptymsg($text{'edit_netnone'});
$ntable->add_link("edit_net.cgi?zone=$in{'zone'}&new=1", $text{'edit_netadd'});

# Show package directories
$p->add_separator();
$pform = new WebminUI::Form();
$p->add_form($pform);
$pform->set_input(\%in);
$ptable = new WebminUI::Table([ $text{'edit_pkgdir'} ], "100%", "ptable");
$pform->add_section($ptable);
$ptable->set_heading($text{'edit_pkg'});
foreach $pkg (@{$zinfo->{'inherit-pkg-dir'}}) {
	if ($zinfo->{'status'} eq 'configured') {
		$ptable->add_row([ &ui_link("edit_pkg.cgi?zone=$in{'zone'}&old=$pkg->{'dir'}",$pkg->{'dir'}) ]);
		}
	else {
		$ptable->add_row([ "<tt>$pkg->{'dir'}</tt>" ]);
		}
	}
$ptable->set_emptymsg($text{'edit_pkgnone'});
if ($zinfo->{'status'} eq 'configured') {
	$ptable->add_link("edit_pkg.cgi?zone=$in{'zone'}&new=1",
			  $text{'edit_pkgadd'});
	}
else {
	$p->add_message($text{'edit_pkgcannot'});
	}

# Show other filesystems
$p->add_separator();
$fform = new WebminUI::Form("edit_fs.cgi");
$p->add_form($fform);
$fform->set_input(\%in);
$ftable = new WebminUI::Table([ $text{'edit_fsdir'},
                              $text{'edit_fsspecial'},
                              $text{'edit_fstype'},
                              $text{'edit_fsmounted'} ], "100%", "ftable");
$fform->add_section($ftable);
$ftable->set_heading($text{'edit_fs'});
foreach $fs (@{$zinfo->{'fs'}}) {
	$ftable->add_row([
		&ui_link("edit_fs.cgi?zone=$in{'zone'}&old=$fs->{'dir'}",$fs->{'dir'}),
		&mount::device_name($fs->{'special'}),
		&mount::fstype_name($fs->{'type'}),
		&get_active_mount($zinfo, $fs) ?
			$text{'yes'} : $text{'no'},
		]);
	}
$ftable->set_emptymsg($text{'edit_fsnone'});
$ftable->add_input(new WebminUI::Submit($text{'edit_fsadd'}));
$ftable->add_input(new WebminUI::Select("type", "ufs",
	[ map { [ $_, &mount::fstype_name($_) ] } &list_filesystems() ]));
$fform->add_hidden("new", 1);
$fform->add_hidden("zone", $in{'zone'});

# Show resource controls
$p->add_separator();
$rform = new WebminUI::Form();
$p->add_form($rform);
$rform->set_input(\%in);
$rtable = new WebminUI::Table([ $text{'edit_rctlname'},
                              $text{'edit_rctlpriv'},
                              $text{'edit_rctllimit'},
                              $text{'edit_rctlaction'}, ], "100%", "rtable");
$rform->add_section($rtable);
$rtable->set_heading($text{'edit_rctl'});
foreach $rctl (@{$zinfo->{'rctl'}}) {
	@values = split(/\0/, $rctl->{'value'});
	local (@privs, @limits, @actions);
	foreach $v (@values) {
		($priv, $limit, $action) = &get_rctl_value($v);
		push(@privs, $text{'rctl_'.$priv});
		push(@limits, $limit);
		push(@actions, $text{'rctl_'.$action});
		}
	$rtable->add_row([
		&ui_link("edit_rctl.cgi?zone=$in{'zone'}&old=$rctl->{'name'}",$rctl->{'name'}),
		join("<br>", @privs),
		join("<br>", @limits),
		join("<br>", @actions),
		]);
	}
$rtable->set_emptymsg($text{'edit_rctlnone'});
$rtable->add_link("edit_rctl.cgi?zone=$in{'zone'}&new=1",
		  $text{'edit_rctladd'});

# Show generic attributes
$p->add_separator();
$gform = new WebminUI::Form();
$p->add_form($gform);
$gform->set_input(\%in);
$gtable = new WebminUI::Table([ $text{'edit_attrname'},
			      $text{'edit_attrtype'},
			      $text{'edit_attrvalue'}, ], "100%", "gtable");
$gform->add_section($gtable);
$gtable->set_heading($text{'edit_attr'});
foreach $attr (@{$zinfo->{'attr'}}) {
	$gtable->add_row([
		&ui_link("edit_attr.cgi?zone=$in{'zone'}&old=$attr->{'name'}",$attr->{'name'}),
		$text{'attr_'.$attr->{'type'}},
		$attr->{'value'},
		]);
	}
$gtable->set_emptymsg($text{'edit_attrnone'});
$gtable->add_link("edit_attr.cgi?zone=$in{'zone'}&new=1",
		  $text{'edit_attradd'});

$p->add_footer("index.cgi", $text{'index_return'});
$p->print();


