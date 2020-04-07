DROP PROCEDURE IF EXISTS "update_thread_%%BOARD%%";

CREATE PROCEDURE "update_thread_%%BOARD%%" (tnum INT)
BEGIN
  UPDATE
    "%%BOARD%%_threads" op
  SET
    op.time_last = (
      COALESCE(GREATEST(
        op.time_op,
        (SELECT MAX(timestamp) FROM "%%BOARD%%" re FORCE INDEX(thread_num_subnum_index) WHERE
          re.thread_num = tnum AND re.subnum = 0)
      ), op.time_op)
    ),
    op.time_bump = (
      COALESCE(GREATEST(
        op.time_op,
        (SELECT MAX(timestamp) FROM "%%BOARD%%" re FORCE INDEX(thread_num_subnum_index) WHERE
          re.thread_num = tnum AND (re.email <> 'sage' OR re.email IS NULL)
          AND re.subnum = 0)
      ), op.time_op)
    ),
    op.time_ghost = (
      SELECT MAX(timestamp) FROM "%%BOARD%%" re FORCE INDEX(thread_num_subnum_index) WHERE
        re.thread_num = tnum AND re.subnum <> 0
    ),
    op.time_ghost_bump = (
      SELECT MAX(timestamp) FROM "%%BOARD%%" re FORCE INDEX(thread_num_subnum_index) WHERE
        re.thread_num = tnum AND re.subnum <> 0 AND (re.email <> 'sage' OR
          re.email IS NULL)
    ),
    op.time_last_modified = (
      COALESCE(GREATEST(
        op.time_op,
        (SELECT GREATEST(MAX(timestamp), MAX(timestamp_expired)) FROM "%%BOARD%%" re FORCE INDEX(thread_num_subnum_index) WHERE
          re.thread_num = tnum)
      ), op.time_op)
    ),
    op.nreplies = (
      SELECT COUNT(*) FROM "%%BOARD%%" re FORCE INDEX(thread_num_subnum_index) WHERE
        re.thread_num = tnum
    ),
    op.nimages = (
      SELECT COUNT(media_hash) FROM "%%BOARD%%" re FORCE INDEX(thread_num_subnum_index) WHERE
        re.thread_num = tnum
    )
    WHERE op.thread_num = tnum;
END;

DROP PROCEDURE IF EXISTS "create_thread_%%BOARD%%";

CREATE PROCEDURE "create_thread_%%BOARD%%" (num INT, timestamp INT)
BEGIN
  INSERT IGNORE INTO "%%BOARD%%_threads" VALUES (num, timestamp, timestamp,
    timestamp, NULL, NULL, timestamp, 0, 0, 0, 0);
END;

DROP PROCEDURE IF EXISTS "delete_thread_%%BOARD%%";

CREATE PROCEDURE "delete_thread_%%BOARD%%" (tnum INT)
BEGIN
  DELETE FROM "%%BOARD%%_threads" WHERE thread_num = tnum;
END;

DROP PROCEDURE IF EXISTS "insert_image_%%BOARD%%";

CREATE PROCEDURE "insert_image_%%BOARD%%" (n_media_hash VARCHAR(25),
 n_media VARCHAR(20), n_preview VARCHAR(20), n_op INT)
BEGIN
  IF n_op = 1 THEN
    INSERT INTO "%%BOARD%%_images" (media_hash, media, preview_op, total)
    VALUES (n_media_hash, n_media, n_preview, 1)
    ON DUPLICATE KEY UPDATE
      media_id = LAST_INSERT_ID(media_id),
      total = (total + 1),
      preview_op = COALESCE(preview_op, VALUES(preview_op)),
      media = COALESCE(media, VALUES(media));
  ELSE
    INSERT INTO "%%BOARD%%_images" (media_hash, media, preview_reply, total)
    VALUES (n_media_hash, n_media, n_preview, 1)
    ON DUPLICATE KEY UPDATE
      media_id = LAST_INSERT_ID(media_id),
      total = (total + 1),
      preview_reply = COALESCE(preview_reply, VALUES(preview_reply)),
      media = COALESCE(media, VALUES(media));
  END IF;
END;

DROP PROCEDURE IF EXISTS "delete_image_%%BOARD%%";

CREATE PROCEDURE "delete_image_%%BOARD%%" (n_media_id INT)
BEGIN
  UPDATE "%%BOARD%%_images" SET total = (total - 1) WHERE media_id = n_media_id;
END;

DROP TRIGGER IF EXISTS "before_ins_%%BOARD%%";

CREATE TRIGGER "before_ins_%%BOARD%%" BEFORE INSERT ON "%%BOARD%%"
FOR EACH ROW
BEGIN
  IF NEW.media_hash IS NOT NULL THEN
    CALL insert_image_%%BOARD%%(NEW.media_hash, NEW.media_orig, NEW.preview_orig, NEW.op);
    SET NEW.media_id = LAST_INSERT_ID();
  END IF;
END;

DROP TRIGGER IF EXISTS "after_ins_%%BOARD%%";

CREATE TRIGGER "after_ins_%%BOARD%%" AFTER INSERT ON "%%BOARD%%"
FOR EACH ROW
BEGIN
  IF NEW.op = 1 THEN
    CALL create_thread_%%BOARD%%(NEW.num, NEW.timestamp);
  END IF;
  CALL update_thread_%%BOARD%%(NEW.thread_num);
END;

DROP TRIGGER IF EXISTS "after_del_%%BOARD%%";

CREATE TRIGGER "after_del_%%BOARD%%" AFTER DELETE ON "%%BOARD%%"
FOR EACH ROW
BEGIN
  CALL update_thread_%%BOARD%%(OLD.thread_num);
  IF OLD.op = 1 THEN
    CALL delete_thread_%%BOARD%%(OLD.num);
  END IF;
  IF OLD.media_hash IS NOT NULL THEN
    CALL delete_image_%%BOARD%%(OLD.media_id);
  END IF;
END;
