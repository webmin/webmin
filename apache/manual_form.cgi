#!/usr/local/bin/perl
# manual.cgi
# Display a text box for manually editing directives

require './apache-lib.pl';
&ReadParse();
$access{'types'} eq '*' || &error($text{'manual_ecannot'});
if (defined($in{'virt'})) {
	if (defined($in{'idx'})) {
		# directory within virtual server
		($vconf, $v) = &get_virtual_config($in{'virt'});
		$d = $vconf->[$in{'idx'}];
		$title = &text('dir_header', &dir_name($d), &virtual_name($v));
		$return = "dir_index.cgi"; $rmsg = $text{'dir_return'};
		$file = $d->{'file'};
		$start = $d->{'line'}+1; $end = $d->{'eline'}-1;
		}
	else {
		# virtual server (which can have multiple files!)
		($conf, $v) = &get_virtual_config($in{'virt'});
		@files = &unique((map { $_->{'file'} } @$conf), $v->{'file'});
		$title = &text('virt_header', &virtual_name($v));
		$return = "virt_index.cgi"; $rmsg = $text{'virt_return'};
		$file = $in{'editfile'} || $v->{'file'};
		&indexof($file, @files) >= 0 ||
			&error($text{'manual_efile'});
		if ($file eq $v->{'file'}) {
			# Edit stuff include <Virtualhost>
			$start = $v->{'line'}+1; $end = $v->{'eline'}-1;
			}
		else {
			# Edit whole file
			$start = $end = undef;
			}
		}
	}
else {
	if (defined($in{'idx'})) {
		# files within .htaccess file
		$hconf = &get_htaccess_config($in{'file'});
		$d = $hconf->[$in{'idx'}];
		$file = $in{'file'};
		$start = $d->{'line'}+1; $end = $d->{'eline'}-1;
		$title = &text('htfile_header', &dir_name($d),
			       "<tt>$in{'file'}</tt>");
		$return = "htaccess_index.cgi"; $rmsg = $text{'htindex_return'};
		}
	else {
		# .htaccess file
		$file = $in{'file'};
		$title = &text('htindex_header', "<tt>$in{'file'}</tt>");
		$return = "htaccess_index.cgi"; $rmsg = $text{'htindex_return'};
		$dir = "files_index.cgi";
		}
	}
@files = ( $file ) if (!@files);
&ui_print_header($title, $text{'manual_title'}, "");

foreach $h ('virt', 'idx', 'file') {
	if (defined($in{$h})) {
		$hiddens .= &ui_hidden($h, $in{$h}),"\n";
		push(@args, "$h=$in{$h}");
		}
	}
$args = join('&', @args);

# Show file selector (if needed)
if (@files > 1) {
	print &ui_form_start("manual_form.cgi");
	print $text{'manual_editfile'},"\n";
	print &ui_select("editfile", $file,
			 [ map { [ $_ ] } @files ]),"\n";
	print &ui_submit($text{'manual_switch'});
	print $hiddens;
	print &ui_form_end();
	}
else {
	print &text('manual_header', "<tt>$file</tt>"),"<p>\n";
	}

# Show actual editor form
print &ui_form_start("manual_save.cgi", "form-data");
print $hiddens;
print &ui_hidden("editfile", $in{'editfile'}),"\n";

$lref = &read_file_lines($file);
if (!defined($start)) {
	$start = 0;
	$end = @$lref - 1;
	}
for($i=$start; $i<=$end; $i++) {
	push(@buf, $lref->[$i]);
	}

# Display nicely too
&format_config(\@buf);
$buf = join("\n", @buf);

print &ui_textarea("directives", $buf, 15, 80, undef, undef,
		   "style='width:100%'"),"<br>\n";
print &ui_submit($text{'save'});
print &ui_form_end();

&ui_print_footer("$return?$args", $rmsg);

# print_directives(&list, indent)
sub print_directives
{
foreach $c (@{$_[0]}) {
	next if ($c->{'name'} eq 'dummy');
	if ($c->{'type'}) {
		print $_[1],"<",$c->{'name'}," ",$c->{'value'},">\n";
		&print_directives($c->{'members'}, $_[1].' ');
		print $_[1],"</",$c->{'name'},">\n";
		}
	else {
		print $_[1],$c->{'name'}," ",$c->{'value'},"\n";
		}
	}
}

