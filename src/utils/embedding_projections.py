import numpy as np
import pandas as pd
from gensim.models.doc2vec import Doc2Vec


# Define class to compute embeddings
class EmbeddingProjections:
    
    """
    Calculate cosine similarity between indicator embeddings and semantic dimensions.
    
    This class is designed to calculate cosine similarity between indicator embeddings and semantic
    dimensions from a fit Doc2Vec-model. The dimensions are constructed from the word-pairs passed
    to the class. The class has methods for calculating cosine similarity, constructing dimensions,
    and projecting indicator-embeddings onto these dimensions.
    
    Parameters
    ---------
    model : Doc2Vec
        A Doc2Vec-model.
    indicators :list
        A list of indicator-embeddings
    dimension :list
        A list of tuples with each tuple representing a word-pair
    
    Methods
    -------
    cos_similarity(a, b):
        Returns cosine similarity between two vectors, a and b, calculated as the dot
        product between the two, normalised by the length of a and b.
    full_dimension():
        Returns a vector with the average semantic dimension averaged over all word-pairs.
    project_indicators()
        Returns a DataFrame with the indicator-embeddings projected onto the semantic dimension.
    project_words()
        Returns a DataFrame with a list of words projected onto the dimension. If no words are provided,
        the default is to project the words used to construct the semantic dimension.
    """
    
    def __init__(self, model, indicators, dimension):
        
        self.model = model
        self.indicators = indicators
        self.dimension = dimension
        
    @staticmethod
    def cos_similarity(a, b):
        cs = np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))
        return cs
    
    def full_dimension(self):
        dim = np.array([self.model[p[0]] - self.model[p[1]] for p in self.dimension])
        return np.mean(dim, axis=0)
    
    def project_indicators(self):

        full_dim = self.full_dimension()
        
        # Calculating dimension-similarity for each indicator-value
        data = {
            'indicator': [i for i in self.indicators],
            'similarity': [self.cos_similarity(self.model.dv[i], full_dim)
                                    for i in self.indicators]}
        return pd.DataFrame(data)
    
    def project_words(self, words=[]):

        if words == []:
            # If no words a provided, then flatten the dimension-list and
            # project these words onto the scale
            words = [word for pair in self.dimension for word in pair]
        
        full_dim = self.full_dimension()
        
        data = {
            'word': [w for w in words],
            'similarity': [self.cos_similarity(self.model.wv[w], full_dim) for w in words]}

        return pd.DataFrame(data)
    