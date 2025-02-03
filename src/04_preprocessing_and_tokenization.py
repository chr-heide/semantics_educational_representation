# Script to preprocess and tokenize the texts. 

#### IMPORTS ####

import os
import pandas as pd
import numpy as np
from tqdm import tqdm
import re
import spacy
import pickle



#### READING DATA ####

# Reading in data
df = pd.read_csv('data/processed/full_dataset.csv')



#### SPLITTING DATA INTO SUBSETS ####

# Splitting the data into subsets - I make 6 to ensure subsets sizes of less than 100k observations
num_subsets = 10
subset_size = len(df) // num_subsets

# Splitting into subsets and saving as csv
for i in range(num_subsets):

    # Determining indices for subsetting
    start = i * subset_size
    # Special case for the last subset
    if i == num_subsets - 1:
        end = len(df)
    else:
        end = (i + 1) * subset_size
    
    # Subsetting and saving
    subset = df.iloc[start:end]
    subset.to_csv(f'data/python_subsets/df_{i + 10}.csv')



#### FUNCTIONS AND PATTERS FOR PREPROCESSING AND TOKENIZATION ####

# Defining a custom removal pattern, to remove corpus-specific stop-words - this includes
# names, procedural words, and the names of parties.
names = [x[:-1] + '[a-z]+' for x in list(df.speaker.unique())]

procedural = ['[Ll]ovforsla[a-z]+', 'ordfør[a-z]+', 'spørgsmå[a-z]+',
              'forsla[a-z]+', 'L', 'B', '[Hh]r', '[Ff]ru', '[Aa]fstemnin[a-z]+',
              '[Ff]orhandlin[a-z]+', '[Hh]r', '[Ff]ru']
               
parties = ['[Ll]iberal [Aa]llianc[a-z]+', 'LA', '[Dd]et [Kk]onservative [Ff]olkepar[a-z]+', 'KF',
           '[Dd]e [Kk]onservati[a-z]+', 'Venst[a-z]+', '[Dd]ansk [Ff]olkepart[a-z]+',
           '[Nn]ye [Bb]orgerli[a-z]+', '[Dd]e [Rr]adikal[a-z]+', '[Ss]ocialdemokratie[a-z+]',
           '[Ss]ocialdemokra[a-z]+', '[Ss]ocialistis[a-z]+ [Ff]olkepart[a-z]+', 'SF',
           '[Aa]lternative[a-z]+', '[Ee]nhedslist[a-z]+', '[Rr]adika[a-z]+', 'Moderater[a-z]+',
           '[Dd]anmark [Dd]emokrat[a-z]+', 'DD']

removal_words = parties + procedural + names
removal_pattern = r'\b(?:' + '|'.join(removal_words) + r')\b'

# Load spacy-model
#!python -m spacy download da_core_news_sm # uncomment to download the spacy-model
spacy_pipeline = spacy.load('da_core_news_sm')

# From the spacy-model I define a list of danish stop-words
stopwords = sorted(list(spacy_pipeline.Defaults.stop_words))

# Defining a tokenizer - it will lowercase and remove stopwords, punctuation, numbers
# and one-character words
def spacy_tokenizer(docs):
    toks = [[d.lower_ for d in spacy_pipeline(doc)
             if not d.is_punct and not d.is_digit
             and d.text not in stopwords and len(d.text) > 1] 
             for doc in tqdm(docs, desc = "Tokenizing:", leave = True)]
    return toks



#### PREPROCESSING AND TOKENIZATION ####

# Next, I loop over all the subsets, and preprocess and tokenize them all
for f in os.listdir('data/python_subsets'):

    # Print status
    print(f'Now processing: {f}')

    df = pd.read_csv(f'data/python_subsets/{f}')

    # Defining my corpus as the text-column of the data frame
    corpus = list(df['text'])
    
    # I remove these corpus-specific stopwords, along with some weird encoding and consecutive white-spaces
    corpus = [re.sub('\xa0', '', t) for t in corpus]
    corpus = [re.sub(removal_pattern, '', t) for t in corpus]
    corpus = [re.sub(' +', ' ', t) for t in corpus]

    # Tokenizing the corpus while perfoming additional preprocessing
    tokens = spacy_tokenizer(corpus)

    # Saving the tokens
    with open(f'data/tokenized_data/tokenized_{f[:-4]}.pkl', 'wb') as file:
        pickle.dump(tokens, file)
    
# Finally, I load all the tokens and reassemble to one list of tokens

# Empty list of tokens
tokens = []

for f in os.listdir('data/tokenized_data'):

    # Load the tokens
    with open(f'data/tokenized_data/{f}', 'rb') as file:
        loaded_tokens = pickle.load(file)
    
    # Add the tokens to the list of main tokens
    tokens = tokens + loaded_tokens

# Saving the full list of tokens
with open('data/tokenized_data/tokenized_data_full.pkl', 'wb') as file:
    pickle.dump(tokens, file)
