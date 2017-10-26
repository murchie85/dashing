class Dashing.Buildhistory extends Dashing.Widget
    
  ready: ->
    # This is fired when the widget is done being rendered

    
  onData: (data) ->
    # This is fired when the widget receives data

    #extract widget paramaters
    @max_displayed_samples = @get('max_samples')
    @display_job_titles = @get('show_job_titles')
    @display_sample_spacers = @get('sample_spacers')
    
    
    container = $(@node).parent()
    # code from graph.coffee
    widget_width = (Dashing.widget_base_dimensions[0] * container.data("sizex")) + Dashing.widget_margins[0] * 2 * (container.data("sizex") - 1)
    widget_height = (Dashing.widget_base_dimensions[1] * container.data("sizey"))
    
    chart_inner_margin = 40
    
    #calculate canvas size
    canvas_width = widget_width - chart_inner_margin
    canvas_height = widget_height - chart_inner_margin
    
    #calculate sample bar width
    sample_bar_width = 10 

    unless @max_displayed_samples is 0
      
      #adjust if spacers between samples
      if @display_sample_spacers
        sample_bar_width = (canvas_width - @max_displayed_samples) / @max_displayed_samples
      else
       sample_bar_width = canvas_width / @max_displayed_samples
    
    
    #calculate sample bar height
    row_height = 30
    @number_jenkins_jobs = data.jenkins_jobs.length
    
    unless @number_jenkins_jobs is 0
      
      #adjust if spacers between samples
      if @display_sample_spacers
        row_height = (canvas_height - @number_jenkins_jobs) / @number_jenkins_jobs
      else
       row_height = canvas_height / @number_jenkins_jobs
    
      
    #hash Jenkins build status values ('ball color' => HTML colour values)
    #reference: https://github.com/jenkinsci/jenkins/blob/master/core/src/main/java/hudson/model/BallColor.java
    #use a green sample colour for success as opposed to native Jenkins 'blue'

    #NOTE: disabled, aborted and not built states map to the same colour for simplicity
    #all 'xxx_anime' colours represent currently building jobs. 
    #here, they all map to the same sample colour for simplicity
    
    @jenkins_job_status_colour_map =
      red: "#FE2E2E"
      yellow: "#FACC2E"
      blue: "#64FE2E"
      grey: "#A4A4A4"
      disabled: "#6E6E6E"
      aborted: "#6E6E6E"
      nobuilt: "#6E6E6E"
      red_anime: "#D8D8D8"
      blue_anime: "#D8D8D8"
      grey_anime: "#D8D8D8"
      disabled_anime: "#D8D8D8"
      aborted_anime: "#D8D8D8"
      nobuilt_anime: "#D8D8D8"
    
    #remove child elements of previously rendered canvas object
    if $("#buildhistorychart")
      $("#buildhistorychart").empty()
    
    #create new canvas object
    @raphael_canvas = Raphael("buildhistorychart", canvas_width, canvas_height )
    
    
    y_index = 0
    
    #loop through job status data and render to widget
    for job_entry of data.jenkins_jobs
      extracted_job_entry = data.jenkins_jobs[job_entry]
      #render status history for an entire job
      @_render_job_status_row @raphael_canvas, 0, y_index, sample_bar_width, row_height, extracted_job_entry

      #increment row
      y_index = y_index + row_height    
      
      #add spacer if required
      if @display_sample_spacers
        y_index = y_index + 1
    
    
  # This function renders the build status history for a single job
  _render_job_status_row: (@raphael_canvas, row_x, row_y, sample_bar_width, height, job_object) ->

    #draw status sample bars
    num_samples = job_object.build_status.length
    x_index = row_x

    #only draw samples if there is data to be drawn...
    unless num_samples is 0
      for job_status_entry of job_object.build_status
        job_status = job_object.build_status[job_status_entry]

        #render rectangle for single sample
        rect_attributes =
        stroke: "none"
        fill: @jenkins_job_status_colour_map[job_status.status]
        
        @raphael_canvas.rect(x_index, row_y, sample_bar_width, height).attr rect_attributes

        #draw job title if required
        if @display_job_titles
          @_render_job_title(@raphael_canvas, row_x, row_y, height, job_object.job_name)  
        
        #increment X index
        x_index = x_index + sample_bar_width

        #add spacer if required
        if @display_sample_spacers
          x_index = x_index + 1
        

          
  #this function draws a job title 
  _render_job_title: (@raphael_canvas, row_x, row_y, height, title) ->

    #job title text font
    txt_attributes =
    font: "8px Fontin-Sans, Arial"
    stroke: "none"
    fill: "#000"
    "text-anchor": "start"
    opacity: 0.03

    #render job title text
    @raphael_canvas.text(row_x, row_y + (height / 2), title).attr txt_attributes