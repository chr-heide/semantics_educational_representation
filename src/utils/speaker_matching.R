# A function to match speakers to biographies using fuzzy string matching

library(stringdist)

fuzzy_match_speakers <- function(unmatched_speakers, mp_bios) {
  # Extract speaker names from both data frames
  unmatched_names <- unmatched_speakers$speaker
  mp_names <- mp_bios$speaker
  
  # Find the best match for each unmatched speaker in the mp_bios speakers
  matches <- sapply(unmatched_names, function(name) {
    best_match_index <- amatch(name, mp_names, maxDist = Inf)
    if (!is.na(best_match_index)) {
      matched_name <- mp_names[best_match_index]
    } else {
      matched_name <- NA
    }
    return(matched_name)
  })
  
  # Calculate matching scores
  match_scores <- mapply(function(unmatched, matched) {
    if (is.na(matched)) 
      return(NA)
    else
      return(stringdist(unmatched, matched, method = "jw")) # using Jaro-Winkler distance
  }, unmatched_names, matches)
  
  # Return a data frame with original names, their matches, and the scores
  return(data.frame(UnmatchedSpeaker = unmatched_names, MatchedSpeaker = matches, Score = match_scores))
}