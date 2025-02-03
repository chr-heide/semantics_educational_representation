# Calculating embedding-projections

#### IMPORTS ####

# Custom class
from utils.embedding_projections import EmbeddingProjections

# Libraries
import numpy as np
import pandas as pd
from gensim.models.doc2vec import Doc2Vec



#### READING DATA AND MODELS ####

# Data
df = pd.read_csv('data/processed/full_dataset.csv')

# Models
m1 = Doc2Vec.load("models/d2v_model_1/d2v_model_1.d2v")
m2 = Doc2Vec.load("models/alternative_d2v_models/d2v_model_2.d2v")
m3 = Doc2Vec.load("models/alternative_d2v_models/d2v_model_3.d2v")
m4 = Doc2Vec.load("models/alternative_d2v_models/d2v_model_4.d2v")
m5 = Doc2Vec.load("models/alternative_d2v_models/d2v_model_5.d2v")
m6 = Doc2Vec.load("models/alternative_d2v_models/d2v_model_6.d2v")
m7 = Doc2Vec.load("models/alternative_d2v_models/d2v_model_7.d2v")



#### DEFINING WORD-PAIRS ####

word_pairs = [
    ("universitet", "erhvervsskole"),
    ("universiteter", "erhvervsskoler"),
    ("universiteterne", "erhvervsskolerne"),
    ("djøf'ere", "hk'ere"),
    ("djøf'er", "hk'er"),
    ("forsker", "håndværker"),
    ("forskere", "håndværkere"),
    ("forskerne", "håndværkerne"),
    ("akademisk", "erhvervsfaglig"),
    ("højtuddannede", "ufaglærte"),
    ("højtuddannet", "ufaglært"),
    ("analysearbejde", "håndværksarbejde"),
    ("kandidatuddannelse", "erhvervsuddannelse"),
    ("kandidatuddannelser", "erhvervsuddannelser"),
    ("kandidatuddannelserne", "erhvervsuddannelserne"),
    ("kandidat", "faglært"),
    ("kandidater", "faglærte"),
    ("akademikere", "fabriksarbejdere"),
    ("akademiker", "fabriksarbejder"),
    ("akademikerne", "erhvervsuddannede"),
    ("forskning", "håndværk"),
    ("forskningen", "håndværket"),
    ("professor", "håndværksmester"),
    ("professorer", "håndværksmestre"),
    ("professoren", "håndværksmesteren"),
    ("ph.d", "grundskole"),
    ("læge", "sosu"),
    ("læger", "sosu'er"),
    ("lægerne", "sosu'erne"),
    ("kandidatgrad", "svendebrev"),
    ("teoretisk", "praktisk"),
    ("økonom", "tømrer"),
    ("økonomer", "tømrerne"),
    ("økonomerne", "tømrerne"),
    ("jurist", "elektriker"),
    ("jurister", "elektrikerne"),
    ("juristerne", "elektrikerne"),
    ("psykolog", "murer"),
    ("psykologer", "murere"),
    ("psykologen", "mureren"),
    ("biolog", "skraldemand"),
    ("biologer", "skraldemænd"),
    ("biologerne", "skraldemændene"),
    ("studerende", "lærlinge")
]



#### PROJECTING INDICATORS ####

# Creating lists to loop through
model_list = [m1, m2, m3, m4, m5, m6, m7]
indicator_list = [("doc_embeddings", list(df.doc_id.dropna().unique())),
                  ("speaker_party_year_embeddings", list(df.speaker_party_year.dropna().unique())),
                  ("speaker_id_embeddings", list(df.id.dropna().unique())),
                  ("party_year_embeddings", list(df.party_year.dropna().unique())),
                  ("education_category_embeddings", list(df.education_category.dropna().unique()))]

# For each model project each indicator
for model in model_list:

    for title, indicator in indicator_list:
        
        # Print title
        print("Projecting", title, "for model", model_list.index(model) + 1)

        # Initiating class
        if model != m7:
            embedding_projetions = EmbeddingProjections(
                model = model,
                indicators = indicator,
                dimension = word_pairs
            )
        else: # Special case for model 7, which has a word lacking
            pairs = [
                ("universitet", "erhvervsskole"),
                ("universiteter", "erhvervsskoler"),
                ("universiteterne", "erhvervsskolerne"),
                ("akademikere", "faglærte"),
                ("akademiker", "faglært"),
                ("akademisk", "erhvervsfaglig"),
                ("teoretisk", "praktisk"),
                ("boglige", "praktiske"),
                ("boglig", "praktisk"),
                ("højtuddannede", "lavtuddannede"),
                ("højtuddannede", "kortuddannede"),
                ("universitetsuddannelse", "erhvervsuddannelse"),
                ("universitetsuddannelser", "erhvervsuddannelser"),
                ("universitetsuddannelserne", "erhvervsuddannelserne"),
                ("abstrakt", "konkret"),
                ("ph.d", "ufaglært"),
                ("højtuddannet", "ufaglært"),
                ("højtuddannede", "ufaglærte")
            ]
            embedding_projetions = EmbeddingProjections(
                model = model,
                indicators = indicator,
                dimension = pairs
            )


        # Projecting the indicator to the scale
        projection = embedding_projetions.project_indicators()

        # Save results
        if model == m1:
            projection.to_csv(f"data/projections/model_1/model_{model_list.index(model) + 1}_{title}.csv",
                              index=False)
        else:
            projection.to_csv(f"data/projections/alternative_models/model_{model_list.index(model) + 1}_{title}.csv",
                              index=False)
        
    # Additional projections for models 2-6
    if model != m1 and model != m7:
        m1_embedding_projections = EmbeddingProjections(
            model = model,
            indicators = ["none"],
            dimension = word_pairs)

        # Creating dimension
        m1_dimension = m1_embedding_projections.full_dimension()

        # Getting the words most similar to the high-education end of the scale
        top_words_high_education = model.wv.most_similar(m1_dimension, topn=50)
        top_words_high_education = [word for word, similarity in top_words_high_education]

        # Getting the words most similar to the low-education end of the scale
        top_words_low_education = model.wv.most_similar(-m1_dimension, topn=50)
        top_words_low_education = [word for word, similarity in top_words_low_education]

        # Combining the two lists
        top_words = top_words_low_education + top_words_high_education

        # Flatten list of word_pairs used to construct the dimension
        used_words = [word for pair in word_pairs for word in pair]

        # Filter the top words to not contain the words used to construct the scale
        top_words = [word for word in top_words if word not in used_words]

        # Projecting the top_words onto the dimension
        top_word_projections = m1_embedding_projections.project_words(words = top_words)

        # Saving the projected top words
        top_word_projections.to_csv(f"data/projections/alternative_models/model_{model_list.index(model) + 1}_top_words.csv",
                                    index=False)
        
        words = ["universitet", "erhvervsskole",
         "universitetsuddannede", "erhvervsuddannede",
         "akademiker", "faglært",
         "akademisk", "erhvervsfaglig",
         "teoretisk", "boglig", "praktisk",
         "højtuddannede", "kortuddannede", "lavtuddannede",
         "universitetsuddannelse", "erhvervsuddannelse",
         "abstrakt", "konkret",
         "ph.d", "ufaglært"]

        # Projecting the words
        used_words_projection = m1_embedding_projections.project_words(words=words)

        # Saving the projection
        used_words_projection.to_csv(f"data/projections/alternative_models/model_{model_list.index(model) + 1}_word_pair_projection.csv",
                                    index=False)




#### TOP WORDS FOR MODEL 1 ####

# Initiating class
m1_embedding_projections = EmbeddingProjections(
    model = m1,
    indicators = ["none"],
    dimension = word_pairs)

# Creating dimension
m1_dimension = m1_embedding_projections.full_dimension()

# Getting the words most similar to the high-education end of the scale
top_words_high_education = m1.wv.most_similar(m1_dimension, topn=50)
top_words_high_education = [word for word, similarity in top_words_high_education]

# Getting the words most similar to the low-education end of the scale
top_words_low_education = m1.wv.most_similar(-m1_dimension, topn=50)
top_words_low_education = [word for word, similarity in top_words_low_education]

# Combining the two lists
top_words = top_words_low_education + top_words_high_education

# Flatten list of word_pairs used to construct the dimension
used_words = [word for pair in word_pairs for word in pair]

# Filter the top words to not contain the words used to construct the scale
top_words = [word for word in top_words if word not in used_words]

# Projecting the top_words onto the dimension
top_word_projections = m1_embedding_projections.project_words(words = top_words)

# Saving the projected top words
top_word_projections.to_csv("data/projections/model_1/model_1_top_words.csv",
                            index=False)



#### PROJECTING THE WORD PAIRS BACK TO THE DIMENSION ####

# Defining the words to be projected
words = ["universitet", "erhvervsskole",
         "universitetsuddannede", "erhvervsuddannede",
         "akademiker", "faglært",
         "akademisk", "erhvervsfaglig",
         "teoretisk", "boglig", "praktisk",
         "højtuddannede", "kortuddannede", "lavtuddannede",
         "universitetsuddannelse", "erhvervsuddannelse",
         "abstrakt", "konkret",
         "ph.d", "ufaglært"]

# Projecting the words
used_words_projection = m1_embedding_projections.project_words()

# Saving the projection
used_words_projection.to_csv("data/projections/model_1/model_1_word_pair_projection.csv",
                             index=False)
