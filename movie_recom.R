# R Movie Recommendation System
# Version: 1.0.0

required_packages <- c('dplyr', 'tidyr', 'tm', 'SnowballC', 'stringr', 'proxy', 'logger')

load_packages <- function(packages) {
  for (pkg in packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      tryCatch({
        install.packages(pkg, dependencies = TRUE)
      }, error = function(e) {
        stop(paste("Failed to install package:", pkg))
      })
    }
    library(pkg, character.only = TRUE)
  }
}
load_packages(required_packages)

log_info <- function(msg) {
  log_file <- file.path(getwd(), "movie_recommender.log")
  cat(format(Sys.time(), "[%Y-%m-%d %H:%M:%S] "), msg, "\n", 
      file = log_file, append = TRUE)
  message(msg)
}

config <- list(
  data_path = 'movie_metadata.csv',
  features = c('keywords', 'cast', 'genres', 'director'),
  recommended_movies_count = 5,
  text_preprocessing = list(
    lowercase = TRUE,
    remove_punctuation = TRUE,
    remove_numbers = TRUE,
    remove_stopwords = TRUE,
    stem_document = TRUE
  )
)

load_movie_data <- function(file_path) {
  tryCatch({
    log_info(paste("Loading movie data from", file_path))
    data <- read.csv(file_path, stringsAsFactors = FALSE)

    missing_columns <- setdiff(config$features, names(data))
    if (length(missing_columns) > 0) {
      stop(paste("Missing columns:", paste(missing_columns, collapse = ", ")))
    }
    
    return(data)
  }, error = function(e) {
    log_info(paste("Error loading data:", e$message))
    stop(e)
  })
}

preprocess_text <- function(corpus) {
  log_info("Starting text preprocessing")
  
  if (config$text_preprocessing$lowercase) {
    corpus <- tm_map(corpus, content_transformer(tolower))
  }
  
  if (config$text_preprocessing$remove_punctuation) {
    corpus <- tm_map(corpus, removePunctuation)
  }
  
  if (config$text_preprocessing$remove_numbers) {
    corpus <- tm_map(corpus, removeNumbers)
  }
  
  if (config$text_preprocessing$remove_stopwords) {
    corpus <- tm_map(corpus, removeWords, stopwords("english"))
  }
  
  if (config$text_preprocessing$stem_document) {
    corpus <- tm_map(corpus, stemDocument)
  }
  
  return(corpus)
}

movie_recommender <- function(data, movie_title) {
  tryCatch({
    data$combined_features <- apply(data[, config$features], 1, 
                                    function(x) paste(x, collapse = ' '))
    corpus <- Corpus(VectorSource(data$combined_features))
    corpus <- preprocess_text(corpus)
    dtm <- DocumentTermMatrix(corpus)
    count_matrix <- as.matrix(dtm)

    cosine_sim <- proxy::simil(count_matrix, method = "cosine")
    get_title_from_index <- function(index) data$title[index]
    get_index_from_title <- function(title) which(data$title == title)
    movie_index <- get_index_from_title(movie_title)
    
    if (length(movie_index) == 0) {
      stop(paste("Movie not found:", movie_title))
    }
    
    similar_movies <- as.vector(cosine_sim[movie_index, ])
    sorted_indices <- order(similar_movies, decreasing = TRUE)
    recommended_indices <- sorted_indices[2:(config$recommended_movies_count + 1)]
    recommended_titles <- sapply(recommended_indices, get_title_from_index)
    
    log_info(paste("Recommendations for", movie_title, ":", 
                   paste(recommended_titles, collapse = ", ")))
    
    return(recommended_titles)
  }, error = function(e) {
    log_info(paste("Recommendation error:", e$message))
    return(NULL)
  })
}

main <- function() {
  tryCatch({
    movie_data <- load_movie_data(config$data_path)
    movie_data[config$features] <- lapply(movie_data[config$features], 
                                          function(x) replace(x, is.na(x), ''))
    example_movie <- 'The Social Network'
    recommendations <- movie_recommender(movie_data, example_movie)
    
    if (!is.null(recommendations)) {
      cat("Recommended Movies:\n")
      print(recommendations)
    }
  }, error = function(e) {
    log_info(paste("Execution failed:", e$message))
  })
}

main()
