package MT::LookupObject::Tags;

use strict;

sub plugin {
    MT->component('LookupObject');
}

sub hdlr_lookup_object {
    my ( $ctx, $args, $cond ) = @_;
    my $tag = $ctx->stash('tag');

    # Object class and model
    my $class = delete $args->{class}
        or return $ctx->error(plugin->translate('mt:[_1] requires [_2] modifier.', $tag, 'class'));
    my $model = MT->model($class)
        or return $ctx->error(plugin->translate('Unknown object class: [_1]', $class));

    # Common args
    my $blog_id = delete $args->{blog_id};
    $blog_id = undef unless $model->has_column('blog_id');
    my $pre_fetch = delete $args->{pre_fetch};
    my $as_vars = delete $args->{as_vars};

    # Sort args
    my %query_args;
    if ( my $sort = delete $args->{sort} ) {
        $query_args{sort} = $sort if $model->has_column($sort);
        if ( my $direction = delete $args->{direction} ) {
            $query_args{direction} = $direction;
        }
    }

    # Actual column filters
    my @filters = sort {
        $a cmp $b
    } grep {
        $model->has_column($_)
    } keys %$args;

    my $obj;
    if ( $pre_fetch && 1 == scalar @filters ) {

        # In the case of pre fetch
        my $col = shift @filters;
        my $value = $args->{$col};

        my $tables = ( $ctx->{__stash}{__lookup_tables} ||= {} );
        my $table = ( $tables->{$class} ||= {} );

        my $blog_key = $blog_id;
        $blog_key = '' unless defined $blog_key;

        my $blog_table = ( $table->{$blog_key} ||= {} );
        my $hash = $blog_table->{$col};
        unless ( $hash ) {
            my %terms;
            $terms{blog_id} = $blog_id if defined $blog_id;

            my %hash = map {
                $_->$col => $_
            } grep {
                defined $_->$col
            } $model->load(\%terms, \%query_args);

            $hash = $blog_table->{$col} = \%hash;
        }

        $obj = $hash->{$value};
    } else {

        # Query database
        my %query_terms = map {
            $_ => $args->{$_}
        } @filters;
        $query_terms{blog_id} = $blog_id if defined $blog_id;

        $obj = $model->load(\%query_terms, \%query_args);
    }

    # Empty if not found
    return '' unless $obj;

    # Build inside
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $obj_blog_id = $obj->has_column('blog_id') ? $obj->blog_id : 0;
    my $obj_blog = $obj_blog_id
        ? ( MT->model('blog')->load($obj_blog_id) || MT->model('website')->load($obj_blog_id) )
        : undef;

    my @locals;
    if ( $as_vars ) {
        @locals = sort { $a cmp $b } @{$model->column_names};
    }

    my $stash_vars = $ctx->{__stash}{vars};
    local @$stash_vars{@locals} = map { $obj->$_ || '' } @locals;
    local $ctx->{__stash}{blog} = $obj_blog;
    local $ctx->{__stash}{$class} = $obj;
    defined( my $out = $builder->build($ctx, $tokens, $cond) )
        or return $ctx->error($builder->errstr);

    $out;
}

sub hdlr_lookup_entry {
    $_[1]->{class} = 'entry';
    hdlr_lookup_object(@_);
}

sub hdlr_lookup_page {
    $_[1]->{class} = 'page';
    hdlr_lookup_object(@_);
}

1;