/* Data processing */

-- Extract the featured artists and create a separate column labeled 'artists2'
ALTER TABLE TopSpotifySongs2018
ADD artists2 AS CASE
		WHEN name LIKE '%(%' THEN SUBSTRING(name, CHARINDEX('(', name), LEN(name) - CHARINDEX('(', name) + 1)
		END;


-- Create a column called 'featured'
ALTER TABLE TopSpotifySongs2018
ADD featured NVARCHAR(100);


-- Identify by binary whether the song has a featured artist or not and assign to 'featured'
UPDATE TopSpotifySongs2018
SET featured = CASE
				WHEN artists2 IS NOT NULL THEN 1
				ELSE 0
				END;


/* Extract only the song title from the name column and 
set those extracted names into a new column labeled 'modified_name' */
ALTER TABLE TopSpotifySongs2018
ADD modified_name AS CASE
				WHEN CHARINDEX('(', name) > 0 
				THEN LEFT(name, CHARINDEX('(', name) - 2)
				ELSE name 
				END; 


/* Transform the case for artists, artists2, and modified_name
Create the 'cleaned_name' column */
ALTER TABLE TopSpotifySongs2018
ADD cleaned_name NVARCHAR(100);


-- Change the case in 'modified_name' column for consistency in values and assign values to cleaned_name
UPDATE TopSpotifySongs2018
SET cleaned_name = LOWER(modified_name);


-- Create the 'cleaned_artists' column
ALTER TABLE TopSpotifySongs2018
ADD cleaned_artists NVARCHAR(100);


-- Change the case in 'artists' column for consistency in values and assign values to cleaned_artists
UPDATE TopSpotifySongs2018
SET cleaned_artists = LOWER(artists);


-- Create the 'cleaned_artists_2' column
ALTER TABLE TopSpotifySongs2018
ADD cleaned_artists_2 NVARCHAR(100);


-- Change the case in 'artists2' column for consistency in values and assign values to cleaned_artists_2
UPDATE TopSpotifySongs2018
SET cleaned_artists_2 = LOWER(artists2);


/* Note: I created artists2 to separate the featured artists in parentheses from the song titles. I reassigned values of artists2 
to cleaned_artists_2 beacuse artists2 is a computed column and could not be modified. So, I made cleaned_artists_2 as an empty column to
then fill with the manipulated values from artists2 */

------------------------------------------------------------------------------------------------------------------------
-- Manipulating time values for more insights during analysis ----------------------------------------------------------

-- Extract seconds from the 'duration_ms' and assign to column labeled 'duration_s (s means seconds)
ALTER TABLE TopSpotifySongs2018
ADD duration_s AS (duration_ms / 1000);


-- Extract minutes from the 'duration_s' and assign to column labeled 'duration_m (m means minutes)
ALTER TABLE TopSpotifySongs2018
ADD duration_m AS CAST(ROUND(((duration_ms / 1000.0) / 60.0), 2) 
				AS DECIMAL(4,2));

----------------------------------------------------------------------------------------------------------------

-- Create a new table by assigining the old table to it
SELECT * INTO CleanedTopSpotifySongs2018
FROM TopSpotifySongs2018;


-- Drop redundant columns from the new tabel
ALTER TABLE CleanedTopSpotifySongs2018
DROP COLUMN name, artists, artists2, modified_name;


-- Rename key column to song_key so key column name does not conflict with the keyword 'key'
EXEC sp_rename 'CleanedTopSpotifySongs2018.key', 'song_key', 'COLUMN';


-- Evaluate new table
SELECT *
FROM CleanedTopSpotifySongs2018;

------------------------------------------------------------------------------------------------------------------

/* Artist Analysis */

-- Which artists' had the most Top 100 songs?
SELECT cleaned_artists AS artist,
		COUNT(cleaned_name) AS song_count,
		CAST(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM CleanedTopSpotifySongs2018),2) AS Decimal (4,2)) AS song_percentage
FROM CleanedTopSpotifySongs2018
GROUP BY cleaned_artists
ORDER BY song_percentage DESC;


-- Which songs have the highest key by artist?
SELECT cleaned_artists AS artists,
		cleaned_name AS song,
		MAX(song_key) AS highest_key
FROM CleanedTopSpotifySongs2018
GROUP BY cleaned_artists, cleaned_name
ORDER BY highest_key DESC;


-- Which songs has the lowest key by artist?
SELECT cleaned_artists AS artists,
		cleaned_name AS song,
		MIN(song_key) AS lowest_key
FROM CleanedTopSpotifySongs2018
GROUP BY cleaned_artists, cleaned_name
ORDER BY lowest_key ASC;


-- Are there more artists in the Top 100 with 'Lil' in their name, or with 'DJ' in their name?
SELECT COUNT(*) AS artisit_count,
	(SELECT COUNT(cleaned_artists)
	FROM CleanedTopSpotifySongs2018
	WHERE cleaned_artists LIKE '%Lil%') AS named_lil_count,
	(SELECT COUNT(cleaned_artists)
	FROM CleanedTopSpotifySongs2018
	WHERE cleaned_artists LIKE '%DJ%') AS named_dj_count
FROM CleanedTopSpotifySongs2018;


-- Which artist(s) have the top 10 danceability?
SELECT TOP 10 cleaned_artists, cleaned_name, 
		CAST(ROUND(danceability, 2) AS DECIMAL(4,2)) AS danceabilty,
		RANK() OVER(ORDER BY danceability DESC) AS ranked_danceablility
FROM CleanedTopSpotifySongs2018
ORDER BY ranked_danceablility ASC;

/* Song Analysis */

-- What is the longest and shortest duration in minutes
SELECT MAX(duration_m) AS longest_song,
		MIN(duration_m) AS shortest_song
FROM CleanedTopSpotifySongs2018;


-- Which songs are the top 5 longest in minutes
SELECT TOP 5 cleaned_artists, cleaned_name, duration_m,
	RANK() OVER(Order BY duration_m DESC) AS song_rank
FROM CleanedTopSpotifySongs2018;


-- Which songs are the top 5 shortest in minutes
SELECT TOP 5 cleaned_artists, cleaned_name, duration_m,
	RANK() OVER(Order BY duration_m ASC) AS song_rank
FROM CleanedTopSpotifySongs2018;


/* What is the average duration of a song with or without a featured artists in milliseconds, seconds and minutes
Song with featured artist (1), song without featured artist (0) */
SELECT featured,
		AVG(duration_ms) AS avg_duration_milliseconds,
		AVG(duration_s) AS avg_duration_seconds,
		AVG(duration_m) AS avg_duration_minues
FROM CleanedTopSpotifySongs2018
GROUP BY featured;


-- What are the songs with featured artists?
SELECT cleaned_name AS song, cleaned_artists AS artitst, 
		cleaned_artists_2 AS featured_artist
FROM CleanedTopSpotifySongs2018
WHERE featured = 1;


/* What is longest song based on liveliness 
liveliness determined by (mid to high danceability, mid to high energy, and more than 60 valence) */
WITH liveliness AS (
SELECT cleaned_artists, cleaned_name, danceability, energy, valence, duration_m,
		(SELECT AVG(danceability)
		FROM CleanedTopSpotifySongs2018) AS avg_danceability,
		(SELECT AVG(energy)
		FROM CleanedTopSpotifySongs2018) AS avg_energy,
		(SELECT AVG(valence)
		FROM CleanedTopSpotifySongs2018) AS positive_feel
FROM CleanedTopSpotifySongs2018
)
SELECT cleaned_artists, cleaned_name, danceability, energy, valence, duration_m
FROM liveliness 
WHERE danceability > avg_danceability
		AND energy > avg_energy
		AND valence > 0.60
ORDER BY duration_m DESC,
		danceability DESC,
		energy DESC;


/* What is longest song with mellowness 
mellowness determined by (mid to low danceability and mid to low energy) */
WITH mellowness AS (
SELECT cleaned_artists, cleaned_name, danceability, energy, valence, duration_m,
		(SELECT AVG(danceability)
		FROM CleanedTopSpotifySongs2018) AS avg_danceability,
		(SELECT AVG(energy)
		FROM CleanedTopSpotifySongs2018) AS avg_energy,
		(SELECT AVG(valence)
		FROM CleanedTopSpotifySongs2018) AS negative_feel
FROM CleanedTopSpotifySongs2018
)
SELECT cleaned_artists, cleaned_name, danceability, energy, valence, duration_m
FROM mellowness 
WHERE danceability < avg_danceability
		AND energy < avg_energy
		AND valence < 0.40
ORDER BY duration_m DESC,
		danceability ASC,
		energy ASC;


-- Songs with high/low valence against danceability
WITH mood AS (
SELECT cleaned_artists, cleaned_name, danceability,
		CASE WHEN valence >= 0.60 THEN 'high_valence'
			WHEN valence <= 0.40 THEN 'low_valence'
			ELSE 'moderate'
			END AS song_feel
FROM CleanedTopSpotifySongs2018
)
SELECT cleaned_artists AS artists, cleaned_name AS song, 
	CAST(ROUND(danceability, 2) AS DECIMAL(4,2)) AS danceability, song_feel,
	COUNT(cleaned_artists) OVER(PARTITION BY cleaned_artists, song_feel) AS song_count
FROM mood
ORDER BY song_count DESC


/* Which songs are associated with euphoric, euthymic, or sad moods based on valence score
PERCENT_RANK was used to get a rank of the valence based on percetile
NTILE was used to get thirds of the valence percentiles as reference to construct the range of valence moods
Valence moods are positive affect (happy), euthymic (netral, content mood), negative affect (sad) */
WITH valence_percentiles AS (
	SELECT cleaned_name AS song,
			valence,
			PERCENT_RANK() OVER(ORDER BY valence ASC) AS percent_rank_valence 
	FROM CleanedTopSpotifySongs2018),

valence_thirds AS (
SELECT song,
		percent_rank_valence,
		NTILE(3) OVER(ORDER BY percent_rank_valence ASC) AS third
FROM valence_percentiles
)
SELECT song,
		percent_rank_valence,
		CASE WHEN percent_rank_valence >= 0.67 THEN 'euphoria'
				WHEN percent_rank_valence <= 0.67 AND percent_rank_valence > 0.34 THEN 'euthymic'
				WHEN percent_rank_valence < 0.34 THEN 'sad'
				ELSE 'none' END AS song_affect
FROM valence_thirds