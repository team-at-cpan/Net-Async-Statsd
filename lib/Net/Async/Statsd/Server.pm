package Net::Async::Statsd::Server;

use strict;
use warnings;

use parent qw(IO::Async::Notifier);

=head1 NAME

Net::Async::Statsd::Server - asynchronous server for Etsy's statsd protocol

=head1 SYNOPSIS

 use Future;
 use IO::Async::Loop;
 use Net::Async::Statsd::Server;
 my $loop = IO::Async::Loop->new;
 $loop->add(my $statsd = Net::Async::Statsd::Server->new(
   port => 3001,
 ));

=head1 DESCRIPTION

Provides an asynchronous server for the statsd API.

=head1 METHODS

All public methods return a L<Future> indicating when the write has completed.
Since writes are UDP packets, there is no guarantee that the remote will
receive the value, so this is mostly intended as a way to detect when
statsd writes are slow.

=cut

sub host { shift->{host} }
sub port { shift->{port} }

=head2 listen

Establishes the underlying UDP socket.

=cut

sub connect {
	my ($self) = @_;
	# IO::Async::Loop
	$self->loop->listen(
		family    => 'inet',
		socktype  => 'dgram',
		service   => $self->port,
		host      => $self->host,
		on_socket => $self->curry::on_socket,
	);
}

=head2 on_socket

Called when the socket is established.

=cut

sub on_socket {
	my ($self, $sock) = @_;
	$self->debug_printf("UDP socket established: %s", $sock->write_handle->sockhost_service);
	$sock->configure(
		on_recv       => $self->curry::weak::on_recv,
		on_recv_error => $self->curry::weak::on_recv_error,
	);
	$self->add_child($sock);
}

=head2 on_recv

Called if we receive data.

=cut

sub on_recv {
	my ($self, undef, $dgram, $addr) = @_;
	$self->debug_printf("UDP packet received from %s", join ':', $self->loop->resolver->getnameinfo(
		addr    => $addr,
		numeric => 1,
		dgram   => 1,
	));
}

=head2 on_recv_error

Called if we had an error while receiving.

=cut

sub on_recv_error {
	my ($self, undef, $err) = @_;
	$self->debug_printf("UDP packet receive error: %s", $err);
}

1;

__END__

=head1 SEE ALSO

=over 4

=item * L<Net::Statsd> - synchronous implementation

=back

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2014. Licensed under the same terms as Perl itself.

