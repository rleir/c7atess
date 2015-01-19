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
                    var $element1 = $(taskPage).find('#statusLine');
                    var $element2 = $(taskPage).find('#tblTasks tbody tr td').filter(":first");
                    // or var $element2 = $(taskPage).find('#tblTasks tbody tr td').filter(":eq( 0 )")
                    setInterval(function () {
                        promise1 = $.ajax({
                            type : "GET",
                            url : "/log",
                            cache: false
                        });
                        // success. update the status line with the log txt
                        promise1.done( function(data) {
                            $element1.text(data);
                        });
                        promise1.fail( function(data) {
                            $element1.text("failed to get log text");
                        });

                        promise2 = $.ajax({
                            type : "GET",
                            url : "/status",
                            cache: false
                        });
                        // success. update the first td of first row with the status text
                        promise2.done( function(data) {
                            $element2.text(data);
                        });
                        // failure. update the first td of first row with the failure message
                        promise2.fail( function(data) {
                            $element2.text('failed to get status');
                        });
                    }, 2000);
                });

                initialised = true;
            }
        } 
    } 
}();
