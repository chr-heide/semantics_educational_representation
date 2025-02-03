# Training the main doc2vec model

#### IMPORTS ####

import pandas as pd
from gensim.models.doc2vec import Doc2Vec, TaggedDocument
import pickle



#### READING DATA ####

# Tokens
with open(f'data/tokenized_data/tokenized_data_full.pkl', 'rb') as file:
    tokenized_docs = pickle.load(file)

# Main data frame
df = pd.read_csv('data/processed/full_dataset.csv')



#### TAGGING DOCUMENTS ####

tagged_documents = []

for i, tokens in enumerate(tokenized_docs):
    tags = [df.loc[i, 'party_year'],
            df.loc[i, 'education_category'],
            df.loc[i, 'doc_id'],
            df.loc[i, 'id'],
            df.loc[i, "speaker_party_year"]]
    tagged_documents.append(TaggedDocument(words=tokens, tags=tags))



#### TRAINING DOC2VEC ####

# Training the model
model = Doc2Vec(
    tagged_documents,
    vector_size=300,
    window=6,
    min_count=10,
    workers=4,
    epochs=20,
    seed = 123,
    dm = 1)

# Saving the model
model.save("models/d2v_model_1/d2v_model_1.d2v")