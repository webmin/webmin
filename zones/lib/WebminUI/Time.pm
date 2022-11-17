package WebminUI::Time;
use WebminUI::Input;
use Time::Local;
use WebminCore;
@ISA = ( "WebminUI::Input" );

=head2 new WebminUI::Time(name, time, [disabled])
Create a new field for selecting a time
=cut
sub new
{
if (defined(&WebminUI::Theme::Time::new)) {
        return new WebminUI::Theme::Time(@_[1..$#_]);
        }
my ($self, $name, $value, $disabled) = @_;
bless($self = { });
$self->set_name($name);
$self->set_value($value);
$self->set_disabled($disabled) if (defined($disabled));
return $self;
}

=head2 html()
Returns the HTML for the time chooser
=cut
sub html
{
my ($self) = @_;
my $rv;
my $val = $self->get_value();
my $hour = ($val/3600) % 24;
my $min = ($val/60) % 60;
my $sec = ($val/1) % 60;
my $name = $self->get_name();
$rv .= &ui_textbox("hour_".$name, pad2($hour), 2,$self->get_disabled()).":".
       &ui_textbox("min_".$name, pad2($min), 2, $self->get_disabled()).":".
       &ui_textbox("sec_".$name, pad2($sec), 2, $self->get_disabled());
return $rv;
}

sub pad2
{
return $_[0] < 10 ? "0".$_[0] : $_[0];
}

sub set_value
{
my ($self, $value) = @_;
$self->{'value'} = timegm(localtime($value));
}

=head2 get_value()
Returns the date as a Unix time number (for 1st jan 1970)
=cut
sub get_value
{
my ($self) = @_;
my $in = $self->{'form'} ? $self->{'form'}->{'in'} : undef;
if ($in && defined($in->{"hour_".$self->{'name'}})) {
	my $rv = $self->to_time($in);
	return defined($rv) ? $rv : $self->{'value'};
	}
elsif ($in && defined($in->{"ui_value_".$self->{'name'}})) {
	return $in->{"ui_value_".$self->{'name'}};
	}
else {
	return $self->{'value'};
	}
}

sub to_time
{
my ($self, $in) = @_;
my $hour = $in->{"hour_".$self->{'name'}};
return undef if ($hour !~ /^\d+$/ || $hour < 0 || $hour > 23);
my $min = $in->{"min_".$self->{'name'}};
return undef if ($min !~ /^\d+$/ || $min < 0 || $min > 59);
my $sec = $in->{"sec_".$self->{'name'}};
return undef if ($sec !~ /^\d+$/ || $sec < 0 || $sec > 59);
return $hour*60*60 + $min*60 + $sec;
}

sub set_validation_func
{
my ($self, $func) = @_;
$self->{'validation_func'} = $func;
}

=head2 validate()
Ensures that the date is valid
=cut
sub validate
{
my ($self) = @_;
my $tm = $self->to_time($self->{'form'}->{'in'});
if (!defined($tm)) {
	return ( $text{'ui_etime'} );
	}
if ($self->{'validation_func'}) {
	my $err = &{$self->{'validation_func'}}($self->get_value(),
					        $self->{'name'},
						$self->{'form'});
	return ( $err ) if ($err);
	}
return ( );
}

=head2 set_auto(auto?)
If set to 1, the time will be automatically incremented by Javascript
=cut
sub set_auto
{
my ($self, $auto) = @_;
$self->{'auto'} = $auto;
if ($auto) {
	# XXX incorrect!!
	my $formno = $self->{'form'}->get_formno();
	$self->{'form'}->add_onload("F=[0]; timeInit(F); setTimeout(\"timeUpdate(F)\", 5000)");
	my $as = $autoscript;
	$as =~ s/NAME/$self->{'name'}/g;
	$self->{'form'}->add_script($as);
	}
}

$autoscript = <<EOF;
function timeInit(F) {
        secs = new Array();
        mins = new Array();
        hours = new Array();
        for(i=0; i<F.length; i++){
                secs[i]  = document.forms[F[i]].sec_NAME;
                mins[i]  = document.forms[F[i]].min_NAME;
                hours[i] = document.forms[F[i]].hour_NAME;
		}
}
function timeUpdate(F) {
        for(i=0; i<F.length; i++){
                s = parseInt(secs[i].value);
                s = s ? s : 0;
                s = s+5;
                if( s>59 ){
                        s -= 60;
                        m = parseInt(mins[i].value);
                        m= m ? m : 0;
                        m+=1;
                        if( m>59 ){
                                m -= 60;
                                h = parseInt(hours[i].value);
                                h = h ? h : 0;
                                h+=1;
                                if( h>23 ){
                                        h -= 24;
                                }
                                hours[i].value  = packNum(h);
                        }
                        mins[i].value  = packNum(m);
                }
        secs[i].value = packNum(s);
	}
        setTimeout('timeUpdate(F)', 5000);
}
function packNum(t) {
        return (t < 10 ? '0'+t : t);
}
EOF

1;

