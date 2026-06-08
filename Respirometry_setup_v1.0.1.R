# A shiny app for creating the .txt files that control the SableSystems Multiplexer.
# version 1.0.1
# by Matias Munoz

#Last update: 5 June 2026

library(shiny)
#library(lubridate)

ui <- fluidPage(
  titlePanel("Channel selection and timing inputs\nfor frog stop-flow respirometry"),
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
  "What to make changes? In the Desktop go to 'Matias 2025' folder, then 'ShinnyApps' folder, and edit the 'Shiny_Respirometry_setup.R' file.",
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
      Selected_Channels = as.numeric(input$channels),
      Initial_Flush_Time = as.numeric(input$initial_flush),
      Sampling_Flush_Time = as.numeric(input$sampling_flush),
      Number_of_Repetitions = as.numeric(input$num_repetitions)
    )
  })
  
  respirometry_data <- reactive({
    req(input$channels)
    
    channels <- sort(as.numeric(input$channels))
    n_reps <- as.numeric(input$num_repetitions)
    initial_flush <- as.numeric(input$initial_flush)
    sampling_flush <- as.numeric(input$sampling_flush)
    
    Seconds <- c()
    Channel <- c()
    Marker <- c()
    
    current_time <- 0
    
    # Initial flush cycle
    for (ch in channels) {
      Seconds <- c(Seconds, current_time)
      Marker <- c(Marker, if (ch == 1) "B" else as.character(ch))
      Channel <- c(Channel, if (ch == 1) 0 else ch - 1)
      current_time <- current_time + initial_flush
    }
    
    # Sampling cycles
    for (rep in 1:n_reps) {
      for (ch in channels) {
        Seconds <- c(Seconds, current_time)
        Marker <- c(Marker, if (ch == 1) "B" else as.character(ch))
        Channel <- c(Channel, if (ch == 1) 0 else ch - 1)
        current_time <- current_time + sampling_flush
      }
    }
    
    # Two final baseline (Channel 1) rows, 900s each
    for (i in 1:2) {
      Seconds <- c(Seconds, current_time)
      Channel <- c(Channel, 0)
      Marker <- c(Marker, "B")
      current_time <- current_time + sampling_flush
    }
    
    data.frame(
      Seconds = Seconds,
      Channel = Channel,
      Marker = Marker,
      stringsAsFactors = FALSE
    )
  })
  
  output$preview_table <- renderTable({
    df <- respirometry_data()
    df$Seconds <- as.integer(df$Seconds)
    df$Channel <- as.integer(df$Channel)
    df
  })
  
  output$final_timing <- renderText({
    df <- respirometry_data()
    final_seconds <- tail(df$Seconds, 1)
    final_minutes <- final_seconds / 60
    final_hours <- final_minutes / 60
    end_time <- Sys.time() + final_seconds
    
    paste0(
      "Total Duration:\n",
      round(final_minutes, 2), " minutes\n",
      round(final_hours, 2), " hours\n\n",
      "Estimated End Time (if you started exactly now):\n",
      format(end_time, "%Y-%m-%d %H:%M:%S")
    )
  })
  
  output$download_txt <- downloadHandler(
    filename = function() {
      paste0("respirometry_schedule_", format(Sys.time(), "%d-%m-%Y"), ".txt")
    },
    content = function(file) {
      write.table(
        respirometry_data(),
        file = file,
        sep = "\t",
        row.names = FALSE,
        col.names = FALSE,
        quote = FALSE
      )
    }
  )
}


# Explicitly launch the app in the default browser
runApp(
  list(ui = ui, server = server),
  launch.browser = TRUE
)