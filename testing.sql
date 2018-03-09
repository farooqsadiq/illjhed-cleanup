select count(*) from UsersALL where nvtgc = 'apl'
SELECT
TOP 20
--count(*)
 u.UserInfo1, u.UserInfo2, u.UserInfo3, u.*
FROM UsersALL u
WHERE u.NVTGC = 'welch'
order by u.UserInfo3 desc

--- Resent transactions with no jhed
--- Resent transactions with no jhed
SELECT
  u.Username,
  u.NVTGC,
  u.Cleared,
  u.UserInfo1,
  t.CreationDate,
  u.UserInfo2,
  u.UserInfo3,
  u.UserInfo4,
  u.UserInfo5,
  u.*,
  t.*
FROM UsersAll u

	INNER JOIN
	(
		SELECT  username,
            MAX(CreationDate) MaxDate
		FROM    Transactions
		GROUP BY username
	) MaxDates ON (u.username = MaxDates.username)

	INNER JOIN Transactions t
		ON
		(
			MaxDates.username = t.username
			AND MaxDates.MaxDate = t.CreationDate
		)
	WHERE
	  u.UserName NOT IN ('MSEL', 'APL', 'AFL', 'SAIS', 'LSC', 'WELCH')
	  AND u.NVTGC = 'WELCH'
	  AND t.CreationDate BETWEEN  '2017-06-01' AND '2017-12-31'
--	  AND t.CreationDate BETWEEN  '2016-01-01' AND '2016-12-31'
--	  AND t.CreationDate BETWEEN  '2015-01-01' AND '2015-12-31'
--	  AND t.CreationDate BETWEEN  '2014-01-01' AND '2014-12-31'
	  AND u.UserInfo1 IS  NULL
	ORDER BY t.CreationDate DESC;

  SELECT
  UserInfo1, *
  FROM UsersALL
  WHERE cleared = 'B'
  AND NVTGC = 'MSEL'
  ORDER BY ExpirationDate DESC




--------
-- Report JHEDs found by Cleared status
SELECT
  NVTGC,
  Cleared,  -- Yes (cleared), No (not cleared), B (blocked), and DIS (disavowed).
  CASE WHEN UserInfo1 IS NOT NULL
    THEN 'JHED'
    ELSE 'NOJHED'
  END AS JHEDStatus,
  COUNT(*) AS Total
FROM UsersALL
GROUP BY CASE WHEN UserInfo1 IS NOT NULL
    THEN 'JHED'
    ELSE 'NOJHED'
END, NVTGC, Cleared
ORDER BY NVTGC, Cleared, JHEDStatus;


---
-- NEW do not have any firstname, lastname and hence have not completed the registration
--
SELECT
 U.UserInfo1,
 U.ExpirationDate,
 T.TransactionDate,
 U.*
FROM UsersALL U
LEFT JOIN Transactions T ON (T.Username = U.UserName)
WHERE
U.NVTGC = 'MSEL'
AND U.Cleared = 'DIS'
ORDER BY U.ExpirationDate ASC


-- Duplicates found
SELECT COUNT(*) Num, UserInfo1
FROM UsersALL
GROUP By UserInfo1
HAVING COUNT(*) > 1
ORDER BY Num DESC

----
-- Check user info
--
DECLARE @user varchar(255);
SET @user = 'reservesOLD';
SELECT
 (select COUNT(*) from Transactions t where t.username = @user) AS Num_Tranactions,
 (select COUNT(*) from Notes n where n.AddedBy = @user) AS Num_Notes,
 (select COUNT(*) from UserNotes un where un.Username = @user) AS Num_UserNotes,
 (select COUNT(*) from Tracking tr where tr.ChangedBy = @user) AS Num_Tracking,
 (select COUNT(*) from History h where h.Username = @user) AS Num_History,
 (select COUNT(*) from WebSession w where w.Username = @user) AS Num_WebSessions,
 (select COUNT(*) from Staff s where s.Username = @user) AS Num_Staff,
 (select COUNT(*) from EventLog el where el.Staff = @user) AS Num_EventLog_Staff,
 (select COUNT(*) from CustomizationTracking ct where ct.ChangedBy = @user) AS Num_CustTracker_Staff

SELECT T.*, U.*
FROM Transactions T
  LEFT JOIN UsersALL U ON ( U.Username = T.UserName )
WHERE T.Username LIKE '2115%'
