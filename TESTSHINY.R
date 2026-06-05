# A shiny app for creating the .txt files that control the SableSystems Multiplexer.
# version 1.0.0 
# by Matias Munoz

#Last update: 5 June 2026

# A shiny app for creating the .txt files that control the SableSystems Multiplexer.
# by Matias Munoz.
# Modified: added 30-min inter-repetition baselines and ggplot2 timeline figure.

library(shiny)
library(ggplot2)

ui <- fluidPage(
  titlePanel("Channel selection and timing inputs for frog stop-flow respirometry"),
  h3("Including long baseline for temperature manipulation"),
  h4("by Matias Munoz"),
  h4("version: 1.0.0 (last update: 05 June 2026)"),
  
  "Use this App to create the .txt files that control the switching of channels in the Flow Multiplexer.
     By default, the files are saved in the Downloads folder, and have today's date in the name file.",
  br(),
  br(),
  "The 'Initial flush time' corresponds to the first flushing of the chambers before obtaining adequate measurements. It's usually a short duration flushing (e.g., default is 2 minutes).",
  br(),
  br(),
  "The 'Sampling flush time' is the amount of time that the chamber is open to the inflow of the pump, and during which air flows into the FSM to analyze the gases. (e.g., default is 10 minutes).",
  br(),
  br(),
  "The 'Inter-repetition baseline time' is the duration of a Channel 1 (Baseline) flush inserted between each sampling repetition to allow temperature to change between repetitions (default is 30 minutes = 1800 seconds).",
  br(),
  br(),
  "What to make changes? In the Desktop go to 'Matias_2026' folder, then 'ShinnyApps' folder, and edit the 'Shiny_Respirometry_setup.R' or 'Shiny_Respirometry_setup_TEMPERATURE.R' files.",
  br(),
  br(),
  "ALWAYS MAKE SURE THE FILE IS CORRECT AFTER DOWNLOADING.",
  br(),
  br(),
  sidebarLayout(
    sidebarPanel(
      checkboxGroupInput(
        inputId = "channels",
        label = "Select channels:",
        choices = list("Channel 1 (Baseline)" = 1, "Channel 2" = 2, "Channel 3" = 3,
                       "Channel 4" = 4, "Channel 5" = 5, "Channel 6" = 6,
                       "Channel 7" = 7, "Channel 8" = 8),
        selected = 1:4
      ),
      
      numericInput(
        inputId = "initial_flush",
        label = "Initial flush time (seconds):",
        value = 120,
        step = 1,
        min = 0
      ),
      
      numericInput(
        inputId = "sampling_flush",
        label = "Sampling flush time (seconds):",
        value = 600,
        step = 1,
        min = 0
      ),
      
      numericInput(
        inputId = "inter_rep_baseline",
        label = "Inter-repetition baseline time (seconds):",
        value = 1800,
        step = 1,
        min = 0
      ),
      
      numericInput(
        inputId = "num_repetitions",
        label = "Number of repetitions:",
        value = 3,
        step = 1,
        min = 1
      ),
      
      downloadButton("download_txt", "Download TXT file")
    ),
    
    mainPanel(
      
      h4("Final timing summary"),
      verbatimTextOutput("final_timing"),
      
      h4("Timeline of channel events"),
      plotOutput("timeline_plot", height = "300px"),
      
      h4("Live preview of respirometry table"),
      tableOutput("preview_table"),
      
      h4("Selected inputs"),
      verbatimTextOutput("output")
      
    )
  )
)

server <- function(input, output, session) {
  output$output <- renderPrint({
    list(
      Selected_Channels      = as.numeric(input$channels),
      Initial_Flush_Time     = as.numeric(input$initial_flush),
      Sampling_Flush_Time    = as.numeric(input$sampling_flush),
      Inter_Rep_Baseline     = as.numeric(input$inter_rep_baseline),
      Number_of_Repetitions  = as.numeric(input$num_repetitions)
    )
  })
  
  respirometry_data <- reactive({
    req(input$channels)
    
    channels         <- sort(as.numeric(input$channels))
    n_reps           <- as.numeric(input$num_repetitions)
    initial_flush    <- as.numeric(input$initial_flush)
    sampling_flush   <- as.numeric(input$sampling_flush)
    inter_rep_base   <- as.numeric(input$inter_rep_baseline)
    
    Seconds <- c()
    Channel <- c()
    Marker  <- c()
    
    current_time <- 0
    
    
    
    # ── Initial flush cycle ────────────────────────────────────────────────────
    for (ch in channels) {
      Seconds <- c(Seconds, current_time)
      Marker  <- c(Marker,  if (ch == 1) "B" else as.character(ch))
      Channel <- c(Channel, if (ch == 1) 0   else ch - 1)
      current_time <- current_time + initial_flush
    }
    
    df1 <- data.frame(Seconds = Seconds, Channel = Channel, Marker  = Marker, stringsAsFactors = FALSE)
    
    
    # ── Final baseline (sampling_flush) ────────────────────────────────────────
    Seconds <- c(Seconds, current_time)
    Marker  <- c(Marker, "B")
    Channel <- c(Channel, 0)

    current_time <- current_time + sampling_flush

    
    
    
    # ── Sampling cycles with 30-min baselines between repetitions ─────────────
    for (rep in 1:n_reps) {
      
      # 30-min inter-repetition baseline — inserted BEFORE each rep except the first
      if (rep > 1) {
        Seconds <- c(Seconds, current_time)
        Channel <- c(Channel, 0)
        Marker  <- c(Marker,  "B")
        current_time <- current_time + inter_rep_base
      }
      
      # Sampling channels for this repetition - exclude Channel 1 baseline
      sampling_channels <- channels[channels > 1]
      for (ch in sampling_channels) {
        Seconds <- c(Seconds, current_time)
        Marker  <- c(Marker, as.character(ch))
        Channel <- c(Channel, ch - 1)
        current_time <- current_time + sampling_flush
      }
    }
    
    
    
    
    # ── Two final baseline (Channel 1) rows, sampling_flush each ──────────────
    for (i in 1:2) {
      Seconds <- c(Seconds, current_time)
      Channel <- c(Channel, 0)
      Marker  <- c(Marker,  "B")
      current_time <- current_time + sampling_flush
    }
    
    data.frame(
      Seconds = Seconds,
      Channel = Channel,
      Marker  = Marker,
      stringsAsFactors = FALSE
    )
  })
  
  
  
  # ── Table preview ────────────────────────────────────────────────────────────
  output$preview_table <- renderTable({
    df <- respirometry_data()
    df$Seconds <- as.integer(df$Seconds)
    df$Channel <- as.integer(df$Channel)
    df
  })
  
  # ── Timing summary ───────────────────────────────────────────────────────────
  output$final_timing <- renderText({
    df            <- respirometry_data()
    final_seconds <- tail(df$Seconds, 1) + as.numeric(input$sampling_flush)
    final_minutes <- final_seconds / 60
    final_hours   <- final_minutes / 60
    end_time      <- Sys.time() + final_seconds
    
    paste0(
      "Total Duration:\n",
      round(final_minutes, 2), " minutes\n",
      round(final_hours,   2), " hours\n\n",
      "Estimated End Time (if you started exactly now):\n",
      format(end_time, "%Y-%m-%d %H:%M:%S")
    )
  })
  
  # ── ggplot2 timeline ─────────────────────────────────────────────────────────
  # output$timeline_plot <- renderPlot({
  #   df <- respirometry_data()
  #   df$Seconds <- as.numeric(df$Seconds)
  #   df$Minutes <- df$Seconds / 60
  #   
  #   # Total experiment duration in minutes (add last interval to get end)
  #   total_min <- (tail(df$Seconds, 1) + as.numeric(input$sampling_flush)) / 60
  #   
  #   # Colour baselines differently from sample channels
  #   df$EventType <- ifelse(df$Marker == "B", "Baseline", "Sample channel")
  #   
  #   ggplot(df, aes(x = Minutes, colour = EventType)) +
  #     geom_vline(aes(xintercept = Minutes, colour = EventType),
  #                linewidth = 0.8, alpha = 0.85) +
  #   
  #       # geom_text(aes(x = Minutes, y = 0.6, label = Marker),
  #       #         angle = 0, vjust = -0.4, hjust = 1.5,
  #       #         size = 3.2, show.legend = FALSE) +
  #     
  #     geom_label(aes(x = Minutes, y = 0.6, label = Marker), 
  #                fill = "white",       # Background color
  #                color = "black",      # Text color
  #                fontface = "bold",
  #                label.size = 0.4,
  #                label.padding = unit(0.25, "lines"), # Padding around text
  #                label.r = unit(0.15, "lines")) +      # Corner radius
  #     
  #     scale_colour_manual(
  #       values = c("Baseline" = "red", "Sample channel" = "steelblue"),
  #       name   = "Event type"
  #     ) +
  #     scale_x_continuous(
  #       name   = "Time (minutes)",
  #       limits = c(0, total_min),
  #       expand = c(0.01, 0)
  #     ) +
  #     scale_y_continuous(limits = c(0, 1), breaks = NULL, name = NULL) +
  #     #theme_minimal(base_size = 13) +
  #     theme_bw()+
  #     theme(
  #       panel.grid.major = element_blank(),
  #       panel.grid.minor   = element_blank(),
  #       axis.text.y        = element_blank(),
  #       axis.ticks.y       = element_blank(),
  #       legend.position    = "top"
  #     ) 
  # })
  
  
  # ── ggplot2 timeline ─────────────────────────────────────────────────────────
  output$timeline_plot <- renderPlot({
    df <- respirometry_data()
    df$Seconds <- as.numeric(df$Seconds)
    df$Minutes <- df$Seconds / 60
    
    # Total experiment duration in minutes (add last interval to get end)
    total_min <- (tail(df$Seconds, 1) + as.numeric(input$sampling_flush)) / 60
    
    # Colour baselines differently from sample channels
    df$EventType <- ifelse(df$Marker == "B", "Baseline", "Sample channel")
    
    # ── Build baseline-interval rectangles ─────────────────────────────────────
    # Each "B" row starts a shaded band that ends at the next event (or total_min)
    baseline_idx <- which(df$Marker == "B")
    
    rect_df <- do.call(rbind, lapply(baseline_idx, function(i) {
      xmin <- df$Minutes[i]
      xmax <- if (i < nrow(df)) df$Minutes[i + 1] else total_min
      data.frame(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf)
    }))
    
    ggplot(df, aes(x = Minutes, colour = EventType)) +
      # Shaded baseline bands drawn first so they sit behind everything
      geom_rect(data = rect_df,
                aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
                inherit.aes = FALSE,
                fill   = "red",
                alpha  = 0.10,
                colour = NA) +
      geom_vline(aes(xintercept = Minutes, colour = EventType),
                 linewidth = 0.8, alpha = 0.85) +
      geom_label(aes(x = Minutes, y = 0.6, label = Marker),
                 fill          = "white",
                 color         = "black",
                 fontface      = "bold",
                 size          = 3.2,
                 label.padding = unit(0.25, "lines"),
                 label.r       = unit(0.15, "lines"),
                 label.size    = 0.4,
                 show.legend   = FALSE) +
      scale_colour_manual(
        values = c("Baseline" = "red", "Sample channel" = "steelblue"),
        name   = "Event type"
      ) +
      scale_x_continuous(
        name   = "Time (minutes)",
        limits = c(0, total_min),
        expand = c(0.01, 0)
      ) +
      scale_y_continuous(limits = c(0, 1), breaks = NULL, name = NULL) +
      theme_bw(base_size = 13) +
      theme(
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.text.y      = element_blank(),
        axis.ticks.y     = element_blank(),
        legend.position  = "top"
      ) +
      ggtitle("Respirometry schedule — channel switching events")
  })
  
  # ── Download handler ─────────────────────────────────────────────────────────
  output$download_txt <- downloadHandler(
    filename = function() {
      paste0("respirometry_schedule_Temp_", format(Sys.time(), "%d-%m-%Y"), ".txt")
    },
    content = function(file) {
      write.table(
        respirometry_data(),
        file      = file,
        sep       = "\t",
        row.names = FALSE,
        col.names = FALSE,
        quote     = FALSE
      )
    }
  )
}

# Explicitly launch the app in the default browser
runApp(
  list(ui = ui, server = server),
  launch.browser = TRUE)