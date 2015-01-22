
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
                    // we do not check that it is not greyed: that is checked at the server, and we just ignore the action
                    // check for valid inputs
                    if (! $(taskPage).find('form').valid()) {
                        return;
                    }
                    var $statusLiElement = $(taskPage).find('#statusLine');

                    var ajaxData = new Object();
                    ajaxData.treePath =  $(taskPage).find('#treePath').val();
                    ajaxData.collID   =  $(taskPage).find('#collID').val();

                    promise4 = $.ajax({
                        type : "POST",
                        url : "/start",
                        contentType : "application/JSON",
                        data : JSON.stringify( ajaxData )
                    });
                    // data : JSON.stringify( { sigName : stop } )

                    // success. update the status line with the log txt
                    promise4.done( function(data) {
                        // zzz setPaused( true) ;
                        $statusLiElement.text(data);
                    });
                    promise4.fail( function(data) {
                        $statusLiElement.text("failed to get log text");
                    });
                });

                // jQuery("#SearchForm").validate({
                $(taskPage).find('form').validate({
                    rules: {
                        // MallMgmtCompanyID: {
                        //   required: true
                        // },
                        // parent: {
                        treePath: {
                            required: function(element) {
                                if(jQuery("#treePath").length < 3 && jQuery("#collID").length < 3){
                                    return false;
                                }
                            }
                        }
                    },
                    messages: {
                        collID: "tree path or Collection ID are Required."
                    },
                    success: function() {
                        // jQuery('#JsErrorMsg').remove();
                        // UpdateSearch();
                    },
                    errorPlacement: function(error, element) {
                        error.appendTo('#statusLine');
                    }
                }); 
                // jQuery("#searchbutton").click(function(){
                //    jQuery("#SearchForm").valid();
                // });

                // create the first table row
                var task = $('form').toObject();
                $('#taskRow').tmpl(task).appendTo($(taskPage).find('#tblTasks tbody'));

                // delete / stop button action (
                $(taskPage).find('#tblTasks tbody tr a').filter(":eq( 2 )").click(function(evt) {
                    evt.preventDefault();
                    var $statusLiElement = $(taskPage).find('#statusLine');

                    var ajaxData = new Object();
                    ajaxData.none = "none";

                    promise3 = $.ajax({
                        type : "POST",
                        url : "/stop",
                        contentType : "application/JSON",
                        data : JSON.stringify( ajaxData )
                    });

                    // success. update the status line with the log txt
                    promise3.done( function(data) {
                        // setPaused( true) ;
                        $statusLiElement.text(data);
                    });
                    promise3.fail( function(data) {
                        $statusLiElement.text("failed to get log text");
                    });
                });

                // pause button action (
                $(taskPage).find('#tblTasks tbody tr a').filter(":eq( 0 )").click(function(evt) {
                    evt.preventDefault();
                    var $statusLiElement = $(taskPage).find('#statusLine');

                    var ajaxData = new Object();
                    ajaxData.sigName = "tstp";

                    promise3 = $.ajax({
                        type : "POST",
                        url : "/pause",
                        contentType : "application/JSON",
                        data : JSON.stringify( ajaxData )
                    });
                    // data : JSON.stringify( { sigName : stop } )

                    // success. update the status line with the log txt
                    promise3.done( function(data) {
                        setPaused( true) ;
                        $statusLiElement.text(data);
                    });
                    promise3.fail( function(data) {
                        $statusLiElement.text("failed to get log text");
                    });
                });

                // unpause button action (almost the same as above)
                $(taskPage).find('#tblTasks tbody tr a').filter(":eq( 1 )").click(function(evt) {
                    evt.preventDefault();
                    var $statusLiElement = $(taskPage).find('#statusLine');

                    var ajaxData = new Object();
                    ajaxData.sigName = "cont";

                    promise3 = $.ajax({
                        type : "POST",
                        url : "/pause",
                        contentType : "application/JSON",
                        data : JSON.stringify( ajaxData )
                    });

                    // success. update the status line with the log txt
                    promise3.done( function(data) {
                        setPaused( false) ;
                        $statusLiElement.text(data);
                    });
                    promise3.fail( function(data) {
                        $statusLiElement.text("failed to get log text");
                    });
                });

                // create a repeating action
                $(function () {
                    var $startNewElement = $(taskPage).find('#startNewJob');
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
                                setPaused( true);
                                $deleteElement.removeClass( "greyed");
                                $startNewElement.addClass( "greyed");
                            } else {
                                setPaused( false);
                                $deleteElement.addClass( "greyed");
                                $startNewElement.removeClass( "greyed");
                            }
                        });
                        // failure. update the first td of first row with the failure message
                        promise2.fail( function(data) {
                            $comLiElement.text('failed to get status');
                        });
                    }, 4000);
                });

                initialised = true;
            }
        } 
    } 
}();

function strcmp ( str1, str2 ) {
    // *     example 1: strcmp( 'waldo', 'owald' );
    // *     returns 1: 1
    // *     example 2: strcmp( 'owald', 'waldo' );
    // *     returns 2: -1
    return ( ( str1 == str2 ) ? 0 : ( ( str1 > str2 ) ? 1 : -1 ) );
}

//    vaar startNewElement = $(taskPage).find('#startNewJob');
// var deleteElement = $(taskPage).find('#tblTasks tbody tr a').filter(":eq( 2 )");

// grey or ungrey the pause keys
// something is running so we can pause or delete it but not start or unpause
function setPaused( nowPaused) {
    var $pauseElement = $(taskPage).find('#tblTasks tbody tr a').filter(":eq( 0 )");
    var $unPauseElement = $(taskPage).find('#tblTasks tbody tr a').filter(":eq( 1 )");
    if( nowPaused) {
        $pauseElement.addClass( "greyed");
        $unPauseElement.removeClass( "greyed");
    } else {
        $pauseElement.removeClass( "greyed");
        $unPauseElement.addClass( "greyed");
    }
}
     //   $deleteElement.removeClass( "greyed");
// $startNewElement).addClass( "greyed");
