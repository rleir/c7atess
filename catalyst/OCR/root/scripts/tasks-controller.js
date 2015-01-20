function strcmp ( str1, str2 ) {
    // *     example 1: strcmp( 'waldo', 'owald' );
    // *     returns 1: 1
    // *     example 2: strcmp( 'owald', 'waldo' );
    // *     returns 2: -1
    return ( ( str1 == str2 ) ? 0 : ( ( str1 > str2 ) ? 1 : -1 ) );
}

tasksController = function() { 
    var taskPage;
    var initialised = false;
    
    return { 
        init : function(page) { 
            if (!initialised) {
                taskPage = page;
                $(taskPage).find('[required="required"]').prev('label').append( '<span>*</span>').children( 'span').addClass('required');
                $(taskPage).find('tbody tr:even').addClass('even');
                                
                $(taskPage).find('tbody tr').click(function(evt) {
                    $(evt.target).closest('td').siblings().andSelf().toggleClass('rowHighlight');
                });
                
                $(taskPage).find('#tblTasks tbody').on('click', '.deleteRow', function(evt) { 
                    evt.preventDefault();
                    $(evt.target).parents('tr').remove(); 
                });
                
                $(taskPage).find('#startNewJob').click(function(evt) {
                    evt.preventDefault();
                    if ($(taskPage).find('form').valid()) {
//                        var task = $('form').toObject();
//                        $('#taskRow').tmpl(task).appendTo($(taskPage).find('#tblTasks tbody'));
                    }
                });

                // create the first table row
                var task = $('form').toObject();
                $('#taskRow').tmpl(task).appendTo($(taskPage).find('#tblTasks tbody'));

                // create a repeating action
                $(function () {
                    var $startNewElement = $(taskPage).find('#startNewJob');
                    var $pauseElement = $(taskPage).find('#tblTasks tbody tr a').filter(":eq( 0 )");
                    var $unPauseElement = $(taskPage).find('#tblTasks tbody tr a').filter(":eq( 1 )");
                    var $deleteElement = $(taskPage).find('#tblTasks tbody tr a').filter(":eq( 2 )");

                    var $statusLiElement = $(taskPage).find('#statusLine');
                    var $comLiElement = $(taskPage).find('#tblTasks tbody tr td').filter(":first");
                    // or var $comLiElement = $(taskPage).find('#tblTasks tbody tr td').filter(":eq( 0 )")
                    setInterval(function () {
                        promise1 = $.ajax({
                            type : "GET",
                            url : "/log",
                            cache: false
                        });
                        // success. update the status line with the log txt
                        promise1.done( function(data) {
                            $statusLiElement.text(data);
                        });
                        promise1.fail( function(data) {
                            $statusLiElement.text("failed to get log text");
                        });

                        promise2 = $.ajax({
                            type : "GET",
                            url : "/status",
                            cache: false
                        });
                        // success. update the first td of first row with the status text
                        promise2.done( function(data) {
                            $comLiElement.text(data);
                            console.log(data);
                            if( strcmp( data , "") != 0) {
                                // something is running s we can pause or delete it but not start or unpause
                                $pauseElement.removeClass( "greyed");
                                $deleteElement.removeClass( "greyed");
                                $startNewElement.addClass( "greyed");
                                $unPauseElement.addClass( "greyed");
                            } else {
                                $pauseElement.addClass( "greyed");
                                $deleteElement.addClass( "greyed");
                                $startNewElement.removeClass( "greyed");
                                $unPauseElement.removeClass( "greyed");
                            }
                        });
                        // failure. update the first td of first row with the failure message
                        promise2.fail( function(data) {
                            $comLiElement.text('failed to get status');
                        });
                    }, 2000);
                });

                initialised = true;
            }
        } 
    } 
}();
