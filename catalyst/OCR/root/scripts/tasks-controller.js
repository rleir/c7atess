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
                
                $(taskPage).find('#saveTask').click(function(evt) {
                    evt.preventDefault();
                    if ($(taskPage).find('form').valid()) {
                        promise = $.ajax({
                            type : "GET",
                            url : "/status",
                            cache: false
                        });
                        var task = $('form').toObject();
                        $('#taskRow').tmpl(task).appendTo($(taskPage).find('#tblTasks tbody'));

                        promise.done( function(data) {
                            $(taskPage).find('#tblTasks tbody tr td').filter(":first").text(data);
                        });
                        promise.fail( function(data) {
                            $(taskPage).find('#tblTasks tbody tr td').filter(":eq( 0 )").text(data);
                        });
                    }
                });
                initialised = true;
            }
        } 
    } 
}();
