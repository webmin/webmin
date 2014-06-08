#!/usr/local/bin/perl
# Show a form for displaying the status of one pool

require './bacula-backup-lib.pl';
&ui_print_header(undef,  $text{'poolstatus_title'}, "", "poolstatus");
&ReadParse();

# Show pool selector
$conf = &get_director_config();
@pools =  map { $n=&find_value("Name", $_->{'members'}) }
		&find("Pool", $conf);
@pools = sort { lc($a) cmp lc($b) } @pools;
if (@pools == 1) {
	$in{'pool'} ||= $pools[0];
	}
print &ui_form_start("poolstatus_form.cgi");
print "<b>$text{'poolstatus_show'}</b>\n";
print &ui_select("pool", $in{'pool'},
	 [ map { [ $_ ] } @pools ]);
print &ui_submit($text{'poolstatus_ok'}),"<br>\n";
print &ui_form_end();

if ($in{'pool'}) {
	# Show volumes in this pool
	@volumes = &get_pool_volumes($in{'pool'});

	print &ui_subheading($text{'poolstatus_volumes'});
	$never = "<i>$text{'poolstatus_never'}</i>";
	if (@volumes) {
		print &ui_form_start("delete_volumes.cgi", "post");
		print &ui_hidden("pool", $in{'pool'}),"\n";
		print &select_all_link("d", 1),"\n";
		print &select_invert_link("d", 1),"<br>\n";
		@tds = ( "width=5" );
		print &ui_columns_start([ "",
					  $text{'poolstatus_name'},
					  $text{'poolstatus_type'},
					  $text{'poolstatus_first'},
					  $text{'poolstatus_last'},
					  $text{'poolstatus_bytes'},
					  $text{'poolstatus_status'} ],
					"100%", 0, \@tds);
		foreach $v (@volumes) {
			print &ui_columns_row([
				&ui_checkbox("d", $v->{'volumename'}),
				$v->{'volumename'},
				$v->{'mediatype'},
				$v->{'firstwritten'} || $never,
				$v->{'lastwritten'} || $never,
				$v->{'volbytes'},
				$v->{'volstatus'},
				], \@tds);
			}
		print &ui_columns_end();
		print &select_all_link("d", 1),"\n";
		print &select_invert_link("d", 1),"<br>\n";
		print &ui_form_end([ [ "delete",$text{'poolstatus_delete'} ] ]);
		}
	else {
		print "<b>$text{'poolstatus_none'}</b><p>\n";
		}
	}

&ui_print_footer("", $text{'index_return'});

sub joblink
{
return $jobs{$_[0]} ? &ui_link("edit_job.cgi?name=".&urlize($_[0])."","$_[0]") : $_[0];
}

