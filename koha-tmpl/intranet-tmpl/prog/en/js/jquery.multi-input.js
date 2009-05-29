( function( $ ) {
    $.fn.multi_input = function ( options ) {
        var defaults = {
            add: '+',
            remove: '-',
            separator: ', ',
            allow_duplicates: false,
        };

        var opts = $.extend( defaults, options );

        return this.each( function () {
            if ( this.localName.toLowerCase() != 'select' ) return;
            var values = this.options;
            if ( values.length == 1 ) return;
            var add_button = $( '<a class="buttonPlus" href="#" title=">' + opts.add + '</a>' );
            var inputs = [this];

            function remove_duplicates() {
                var taken = [];
                $.each( inputs, function ( i, input ) {
                    $.
                } );
            }

            var space = document.createTextNode( " " );

            $( this ).after( space );

            $( add_button ).click( function ( event ) {
                var new_input = $( inputs[0] ).clone().get( 0 );
                inputs.push( new_input );
                var new_pos = inputs.length - 1;

                if ( new_input.options.length <= 1 ) $( add_button ).hide();

                var sep = document.createTextNode( opts.separator );

                $( sep ).insertAfter( inputs[new_pos - 1] );

                if ( !opts.allow_duplicates ) {
                    $( new_input ).change( function () {
                        remove_duplicates();
                    } ).change();
                }

                $( new_input ).insertAfter( sep );

                return false;
            } ).insertAfter( space );
        } );
    }
} )( jQuery );
