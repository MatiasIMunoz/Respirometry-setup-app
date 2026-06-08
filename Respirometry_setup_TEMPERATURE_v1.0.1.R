# A shiny app for creating the .txt files that control the SableSystems Multiplexer.
# Including long baseline for temperature modification.
# by Matías I. Muñoz (ma.munozsandoval@gmail.com)

app_version <- "1.0.1"
last_update <- "08 June 2026"

library(shiny)
library(ggplot2)

#************************************#
#*
#* User Interface (UI) ----
#*
#***********************************#

ui <- fluidPage(
  
  fluidRow(
    column(
      width = 8,
      height = 2,
      h2("Channel selection and timing inputs for stop-flow respirometry")
    ),
    column(
      width = 4,
      height = 2,
      align = "right",
      tags$div(
        style = "margin-top:15px; color:#666; font-size:14px;",
        strong(paste0("v", app_version)),
        br(),
        paste("Last updated:", last_update)
      )
    )
  ),
  
  h3("Including long baseline for temperature manipulation"),

  p("Use this application to create the .txt files that control the switching of channels in the Flow Multiplexer.
     By default, the files are saved in the Downloads folder, and have today's date in the name file.", style = "font-size: 17px;"),

  p(strong("Initial flush time"),
    " corresponds to the first flushing of the chambers before obtaining adequate measurements. It's usually a short duration flushing (default is 2 minutes = 120 seconds).", style = "font-size: 17px;"),
  
  p(strong("Sampling flush time"),
    " is the amount of time that the chamber is open to the inflow of the pump, and during which air flows into the FSM to analyze the gases (default is 8 minutes = 480 seconds).", style = "font-size: 17px;"),
  
  p(strong("Inter-repetition baseline time"),
    " is the duration of a Channel 1 (Baseline) flush inserted between each sampling repetition to allow temperature to change between repetitions (default is 30 minutes = 1800 seconds).", style = "font-size: 17px;"),
 
  p(strong("Number of repetitions"),
    "is the number of times the respirometry cycle will be repeated.", style = "font-size: 17px;"),
  
  br(),
  h4("Questions? Contact Matías I. Muñoz (ma.munozsandoval@gmail.com)", style = "color: #979797;"),
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
        value = 480,
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
      
      h4("Final timing summary:"),
      verbatimTextOutput("final_timing"),
      
      h4("Live preview of timeline:"),
      plotOutput("timeline_plot", height = "300px"),
      
      h4("Live preview of respirometry table:"),
      div(style = "display: flex; justify-content: center;",tableOutput("preview_table")),
      
      h4("Selected inputs:"),
      verbatimTextOutput("output")
      
    )
  )
)



#************************************#
#*
#* Server ----
#*
#***********************************#


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
    
 
    
 
       
    # ── Final baseline (sampling_flush) ────────────────────────────────────────
    Seconds <- c(Seconds, current_time)
    Marker  <- c(Marker, "B")
    Channel <- c(Channel, 0)
    
    current_time <- current_time + sampling_flush
    
    
    

    
    
    # ── Sampling cycles with 30-min baselines between repetitions ─────────────
    sampling_channels <- channels[channels > 1]   # move outside loop — never changes
    
    for (rep in 1:n_reps) {
      
      if (rep > 1) {
        # 30-min inter-repetition baseline
        Seconds <- c(Seconds, current_time)
        Channel <- c(Channel, 0)
        Marker  <- c(Marker,  "B")
        current_time <- current_time + inter_rep_base
        
        # 2-min flush per channel — only after a baseline, skip on rep 1
        for (ch in sampling_channels) {
          Seconds <- c(Seconds, current_time)
          Marker  <- c(Marker,  as.character(ch))
          Channel <- c(Channel, ch - 1)
          current_time <- current_time + initial_flush
        }
        
        # Add 2-min baseline after flushing the channels with frogs
         Seconds <- c(Seconds, current_time)
         Marker  <- c(Marker, "B")
         Channel <- c(Channel, 0)
         
         current_time <- current_time + initial_flush
         
      }
      
      # Sampling for this repetition
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
      format(end_time, "%d/%B/%Y %H:%M:%S")
    )
  })
 
  
  
  
  
  
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
                 size          = 3.5,
                 label.padding = unit(0.25, "lines"),
                 label.r       = unit(0.15, "lines"),
                 label.size    = 0.6,
                 show.legend   = FALSE) +
      scale_colour_manual(
        values = c("Baseline" = "red", "Sample channel" = "steelblue"),
        name   = "Marker type"
      ) +
      scale_x_continuous(
        name   = "Time (minutes)",
        limits = c(0, total_min),
        expand = c(0.01, 0)
      ) +
      scale_y_continuous(limits = c(0, 1), breaks = NULL, name = NULL) +
      theme_bw(base_size = 15) +
      theme(
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.text.y      = element_blank(),
        axis.ticks.y     = element_blank(),
        legend.position  = "top"
      ) 
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




# Launch the app in the default browser
runApp(
  list(ui = ui, server = server),
  launch.browser = TRUE)




# 
# > sessionInfo()
# R version 4.3.1 (2023-06-16)
# Platform: x86_64-apple-darwin20 (64-bit)
# Running under: macOS 15.4.1
# 
# Matrix products: default
# BLAS:   /System/Library/Frameworks/Accelerate.framework/Versions/A/Frameworks/vecLib.framework/Versions/A/libBLAS.dylib 
# LAPACK: /Library/Frameworks/R.framework/Versions/4.3-x86_64/Resources/lib/libRlapack.dylib;  LAPACK version 3.11.0
# 
# locale:
#   [1] en_US.UTF-8/en_US.UTF-8/en_US.UTF-8/C/en_US.UTF-8/en_US.UTF-8
# 
# time zone: America/Chicago
# tzcode source: internal
# 
# attached base packages:
#   [1] stats     graphics  grDevices utils     datasets  methods   base     
# 
# other attached packages:
#   [1] ggplot2_3.5.2 shiny_1.7.4.1
# 
# loaded via a namespace (and not attached):
#   [1] vctrs_0.6.5        cli_3.6.5          knitr_1.49         rlang_1.1.6        xfun_0.50          generics_0.1.4     promises_1.2.0.1   xtable_1.8-4       glue_1.8.0        
# [10] htmltools_0.5.8.1  httpuv_1.6.11      rsconnect_1.0.1    scales_1.4.0       rmarkdown_2.29     grid_4.3.1         tibble_3.2.1       evaluate_1.0.3     ellipsis_0.3.2    
# [19] fastmap_1.2.0      yaml_2.3.10        lifecycle_1.0.4    compiler_4.3.1     dplyr_1.1.4        RColorBrewer_1.1-3 pkgconfig_2.0.3    Rcpp_1.1.0         rstudioapi_0.15.0 
# [28] later_1.3.1        farver_2.1.2       digest_0.6.37      R6_2.5.1           tidyselect_1.2.0   dichromat_2.0-0.1  pillar_1.10.1      magrittr_2.0.4     withr_3.0.2       
# [37] tools_4.3.1        gtable_0.3.6       mime_0.12    