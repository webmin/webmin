package Method::Generate::BuildAll;
use strict;
use warnings;

use Moo::Object ();
BEGIN { our @ISA = qw(Moo::Object) }
use Sub::Quote qw(quote_sub quotify);
use Moo::_Utils qw(_getglob _linear_isa);

sub generate_method {
  my ($self, $into) = @_;
  quote_sub "${into}::BUILDALL"
    => join('',
      $self->_handle_subbuild($into),
      qq{    my \$self = shift;\n},
      $self->buildall_body_for($into, '$self', '@_'),
      qq{    return \$self\n},
    )
    => {}
    => { no_defer => 1 }
  ;
}

sub _handle_subbuild {
  my ($self, $into) = @_;
  '    if (ref($_[0]) ne '.quotify($into).') {'."\n".
  '      return shift->Moo::Object::BUILDALL(@_)'.";\n".
  '    }'."\n";
}

sub buildall_body_for {
  my ($self, $into, $me, $args) = @_;
  my @builds =
    grep *{_getglob($_)}{CODE},
    map "${_}::BUILD",
    reverse @{_linear_isa($into)};
  '    (('.$args.')[0]->{__no_BUILD__} or ('."\n"
  .join('', map qq{      ${me}->${_}(${args}),\n}, @builds)
  ."    )),\n";
}

1;
