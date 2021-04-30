#!/usr/local/bin/perl
# detach.cgi
# View one attachment from a message

use Socket;
require './mailboxes-lib.pl';
&ReadParse();
&can_user($in{'user'}) || &error($text{'mail_ecannot'});

@folders = &list_user_folders($in{'user'});
$folder = $folders[$in{'folder'}];
@mail = &mailbox_list_mails($in{'idx'}, $in{'idx'}, $folder);
$mail = $mail[$in{'idx'}];
&parse_mail($mail);
@sub = split(/\0/, $in{'sub'});
foreach $s (@sub) {
        # We are looking at a mail within a mail ..
        local $amail = &extract_mail($mail->{'attach'}->[$s]->{'data'});
        &parse_mail($amail);
        $mail = $amail;
        }
$attach = $mail->{'attach'}->[$in{'attach'}];

if ($in{'scale'}) {
	# Scale the gif or jpeg image to 48 pixels high
	local $temp = &transname();
	open(TEMP, ">$temp");
	print TEMP $attach->{'data'};
	close(TEMP);
	$SIG{'CHLD'} = sub { wait; };
	if ($attach->{'type'} eq 'image/gif') {
		($pnmin, $pnmout) = &pipeopen("giftopnm $temp");
		}
	elsif ($attach->{'type'} eq 'image/jpeg') {
		($pnmin, $pnmout) = &pipeopen("djpeg -fast $temp");
		}
	else {
		&dump_erroricon();
		}
	close($pnmin);
	$type = <$pnmout>;
	$size = <$pnmout>;
	unlink($temp);
	$type =~ /^P[0-9]/ || &dump_erroricon();
	$size =~ /(\d+)\s+(\d+)/ || &dump_erroricon();
	($w, $h) = ($1, $2);
	if ($w > 48) {
		$scale = 48.0 / $w;
		}
	else {
		$scale = 48.0 / $h;
		}
	($jpegin, $jpegout) = &pipeopen("pnmscale $scale 2>/dev/null | cjpeg");
	print $jpegin $type;
	print $jpegin $size;
	my $bs = &get_buffer_size();
	while(read($pnmout, $buf, $bs)) {
		print $jpegin $buf;
		}
	close($jpegin);
	close($pnmout);
	print "Content-type: image/jpeg\n\n";
	while(read($jpegout, $buf, $bs)) {
		print $buf;
		}
	close($jpegout);
	}
else {
	# Just output the attachment
	print "X-no-links: 1\n";
	@download = split(/\t+/, $config{'download'});
	if ($in{'type'}) {
                # Display as a specific MIME type
                print "Content-type: $in{'type'}\n\n";
                print $attach->{'data'};
                }
        else {
		# Auto-detect type
                if ($in{'save'}) {
                        # Force download
                        print "Content-Disposition: Attachment; filename=\"$attach->{'filename'}\"\n";
                        }
                if ($attach->{'type'} eq 'message/delivery-status') {
                        print "Content-type: text/plain\n\n";
                        }
                else {
                        print "Content-type: $attach->{'type'}\n\n";
                        }
		}
	if ($attach->{'type'} =~ /^text\/html/i && !$in{'save'}) {
		print &safe_urls(&filter_javascript($attach->{'data'}));
		}
	else {
		print $attach->{'data'};
		}
	}
&pop3_logout_all();

sub dump_erroricon
{
print "Content-type: image/gif\n\n";
open(ICON, "<images/error.gif");
while(<ICON>) { print; }
close(ICON);
exit;
}

# pipeopen(command)
sub pipeopen
{
$pipe++;
local $inr = "INr$pipe";
local $inw = "INw$pipe";
local $outr = "OUTr$pipe";
local $outw = "OUTw$pipe";
pipe($inr, $inw);
pipe($outr, $outw);
if (!fork()) {
	untie(*STDIN);
	untie(*STDOUT);
	open(STDIN, "<&$inr");
	open(STDOUT, ">&$outw");
	close($inw);
	close($outr);
	exec($_[0]);
	print STDERR "exec failed : $!\n";
	exit 1;
	}
close($inr);
close($outw);
return ($inw, $outr);
}
