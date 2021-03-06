library(plotly)
require(heatmaply)
library(shiny)
require(shinyjs)
require(rbokeh)

 # compute a correlation matrix



ui <- fluidPage(
    useShinyjs(),
    div(
        id = "loading_page",
        h1("Loading...")
    ),
    fluidRow(
        column(7,
               plotlyOutput("heat")),
        column(5,
                                        #           textOutput("selection"),
               rbokehOutput("scatterplot")
               )
    )
)

server <- function(input, output, session) {

    if(file.exists("./sample_table.csv")){
        libs <- read.csv("./sample_table.csv",stringsAsFactors=F)$Label..for.QC.report.
        exp.type <- read.csv("./sample_table.csv",stringsAsFactors=F)$Experiment.type
    }else if(file.exists("./sample_table_v2.txt")){
        tmp<- read.table("./sample_table_v2.txt",stringsAsFactors=F,header=T,check.names=F,sep='\t')
        libs <- tmp[,"Library Name"]
        exp.type <- tmp[,"Experiment Type"]
    }else{
        libs <- read.table("./including_libs.txt",stringsAsFactors=F)$V2
    }


    pd <- read.table("./avgOverlapFC.tab")
    pd.log2 <- log2(subset(pd,apply(pd,1,max)>2)+1)

    if(grepl('atac',exp.type[1],ignore.case=T)){
        names(pd.log2)<- libs
    }else{
            idx.control <-  grepl("control",libs,ignore.case=T)
            if(sum(idx.control) == length(libs)){
                names(pd.log2)<- libs
            }else{
                names(pd.log2)<- libs <-  libs[!idx.control]
            }
    }


    correlation <- round(cor(pd.log2,method="spearman"), 3)

    getXYlabel <- function(p=heatmaply(correlation,colors = Reds(n = 9),margins = c(60,100,NA,20))){
        as.character(p$x$layout$xaxis$categoryarray)
    };

    xlab_correct <- getXYlabel()
    hide("loading_page")

    output$heat <- renderPlotly({
        heatmaply(correlation,colors = Reds(n = 9),margins = c(60,100,NA,20))
    })

    output$selection <- renderPrint({
        s <- event_data("plotly_click")
        if (length(s) == 0) {
            "Click on a cell in the heatmap to display a scatterplot"
        } else {
            cat("You selected: \n\n")
            as.list(s)
        }
    })

    output$scatterplot <- renderRbokeh({
        s <- event_data("plotly_click")
        if (length(s)) {
            vars <- c(s[["x"]], s[["y"]])
            cat(vars)
            cat(xlab_correct)
            x.lab<- xlab_correct[vars[2]];y.lab <- xlab_correct[vars[1]]

            figure(data=pd.log2, title=paste0("Spearman's cor=",correlation[x.lab,y.lab],";log2(FC+1)"),
                   tools = c("pan", "wheel_zoom", "box_select",  "reset", "save")) %>%
                ly_hexbin(x.lab, y.lab, xbins = 50,trans=log2,palette="RdYlBu11")%>%
                ly_abline(a=0,b=1)
        } else {
            figure(data=pd.log2,title=paste0("Spearman's cor=",correlation[1,2],";log2(FC+1)"),
                   tools = c("pan", "wheel_zoom", "box_select",  "reset", "save")) %>%
                ly_hexbin(libs[1], libs[2],xbins = 50,trans=log2,palette="RdYlBu11")%>%
                ly_abline(a=0,b=1)
        }
    })
}

shinyApp(ui, server)
