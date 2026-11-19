# Process IR NuC'ed image list to DB

# Variables
image_list <- "C:/Users/stacie.hardy/Work/SMK/Projects/AS__InFlight_KAMERA/Data/NUCedIR/NUCimages_iceSeal2025_fl202_validated-BXH_20261116.csv"
update_schema <- "surv_ice_seals_2025"
update_table <- "tbl_images"
update_field <- "ir_nuc"

# Install libraries
library(tidyverse)
library(RPostgres)
library(DBI)

# Set up working environment
con <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("mml_pep_db"),
  host = Sys.getenv("mml_pep_ip"),
  user = Sys.getenv("mml_pep_user"),
  password = Sys.getenv("mml_pep_user_pw")
)

# Import data and process
## IMAGE LIST
images <- read.csv(image_list, stringsAsFactors = FALSE) %>%
  filter(img_is_calibration == 1) %>%
  select(file_name) %>%
  rename(images = file_name)

images <- images %>%
  mutate(images = basename(images)) %>%
  mutate(
    flight = str_extract(images, "fl[0-9][0-9][0-9]"),
    camera_view = gsub("_", "", str_extract(images, "_[A-Z]_")),
    dt = str_extract(
      images,
      "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9].[0-9][0-9][0-9][0-9][0-9][0-9]"
    )
  )

# Import data to DB
target_table <- Id(
  schema = update_schema,
  table = "temp_images"
)

RPostgres::dbWriteTable(
  con,
  target_table,
  images,
  append = TRUE,
  row.names = FALSE
)
RPostgres::dbSendQuery(
  con,
  paste(
    "UPDATE ",
    update_schema,
    ".",
    update_table,
    " SET ",
    update_field,
    " = \'Y\' WHERE (flight, camera_view, dt) in (SELECT flight, camera_view, dt FROM ",
    update_schema,
    ".temp_images)",
    sep = ""
  )
)
RPostgres::dbSendQuery(
  con,
  paste(
    "UPDATE ",
    update_schema,
    ".",
    update_table,
    " SET ",
    update_field,
    " = \'N\' WHERE ",
    update_field,
    " IS NULL",
    sep = ""
  )
)
RPostgres::dbSendQuery(
  con,
  paste("DROP TABLE ", update_schema, " .temp_images", sep = "")
)
RPostgres::dbDisconnect(con)
rm(con)
