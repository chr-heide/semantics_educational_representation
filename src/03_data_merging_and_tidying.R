# Christian Heide
# 11/05/2024
# Merging the scraped speeches with the ParlSpeech data and adding MP-biographies.
# Also contains all other tidying of the data, which includes preparing the data
# to be tokenized and passed to doc2vec.

# Imports -----------------------------------------------------------------

# Libraries
library(tidyverse)

# Utility functions
source("src/utils/speaker_matching.R")


# Merging data ------------------------------------------------------------

# Importing the ParlSpeech and merging with the scraped speeches
df <- readRDS("data/processed/ParlSpeechV2_ft.rds") |> 
  bind_rows(readRDS("data/processed/scraped_speeches.rds"))

# Creating ID-variable
df <- df |> 
  mutate(id = paste(speaker, party, sep = "_"))

# Importing biographies
mp_bios <- readRDS("data/processed/mp_biographies.rds") |> 
  rename(speaker = name)


# Merging biographies
df <- df |> 
  # First matching on those where I have a valid match
  filter(id %in% mp_bios$id) |> 
  left_join(
    mp_bios |> select(-speaker),
    by = "id") |> 
  # Next matching on those that have changed parties, but keeping the bio-id
  bind_rows(
    df |>
      filter(!(id %in% mp_bios$id)) |> 
      select(-id) |> 
      left_join(
        mp_bios,
        by = "speaker"))

# Next I identify the unmatched speakers
unmatched_speakers <- df |> 
  filter(is.na(education_category) & is.na(education_text))

# I remove the unmatched speakers from the main data frame
df <- df |> 
  filter(!speaker %in% unmatched_speakers$speaker)

# Creating fuzzy string matches
set.seed(999)
matches <- fuzzy_match_speakers(unmatched_speakers = unmatched_speakers |> 
                                  group_by(speaker) |> 
                                  summarise(n = n()) |> 
                                  select(-n),
                                mp_bios = mp_bios)

# Only keeping matches that have a distance of 0.1 or below
matches <- matches |> 
  filter(Score <= 0.1)

# Adding bio-info for the matched speakers and adding back to main data frame
matched_bios <- mp_bios |> 
  right_join(matches |> 
              rename(speaker = MatchedSpeaker),
            by = "speaker") |> 
  mutate(speaker = UnmatchedSpeaker) |> 
  select(-c(UnmatchedSpeaker, Score))

df <- df |> 
  bind_rows(unmatched_speakers |> 
              filter(speaker %in% matched_bios$speaker) |> 
              select(date:iso3country) |> 
              left_join(matched_bios, by = "speaker")) |> 
  arrange(date, speechnumber)


# Tidying -----------------------------------------------------------------

# I start with discarding all speeches from the chair, as these are highly
# procedural. While they could in principle be interesting, about half the speeches
# are from the chair, and from a perspective of computational costs it makes a
# lot of sense to discard them
df <- df |>
  filter(chair == FALSE)

# In the speeches I scraped, I also included speeches by ministers. However, I
# choose to exclude these for two reasons:
# 1) They are not included in the ParlSpeech data, and excluding them ensures
# consistency
# 2) Parties are not avaliable for ministers, which results in them not having
# a biography-id. So purely practical it makes most sense to exclude them.
df <- df |> 
  filter(party != "")

# Next, some of the recent speeches are not avaliable yet, and are simply marked
# with "(Talen er under udarbejdelse)". I discard these.
df <- df[!grepl("\\(Talen er under udarbejdelse\\)", df$text), ]

# I add a column with document ID's
df$doc_id <- paste0("d", seq_len(nrow(df)))

# And I add a column with party-year indicators
df <- df |> 
  mutate(party_year = paste0(party, "_", substr(date, 1, 4)))

# Adding extra columns with speker_party and speaker_party_year indicators
df <- df |> 
  mutate(
    speaker_party = paste0(speaker, "_", party),
    speaker_party_year = paste0(speaker_party, "_", substr(date, 1, 4))
  )

# Finally saving the tidy data
saveRDS(df, "data/processed/full_dataset.rds")

# And saving as .csv to be used in python
write_csv(df, "data/processed/full_dataset.csv")
