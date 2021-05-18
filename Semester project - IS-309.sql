create or replace PACKAGE CAREPORTAL3B_PKG
IS
    pex_error EXCEPTION; -- Package Exception
    pex_error_txt VARCHAR2(100); -- Package Exception

    PROCEDURE CREATE_AGENCY_PP(p_agency_id OUT INTEGER, -- an output parameter
                               p_agency_name IN VARCHAR, -- Must not be NULL
                               p_agency_abbreviation IN VARCHAR,
                               p_agency_website IN VARCHAR,
                               p_agency_email IN VARCHAR, -- Must not be NULL
                               p_agency_email_domain IN VARCHAR,
                               p_agency_address_1 IN VARCHAR,
                               p_agency_address_2 IN VARCHAR,
                               p_agency_city IN VARCHAR, -- Must not be NULL
                               p_state_code IN CHAR, -- Must not be NULL
                               p_agency_type IN VARCHAR,
                               p_agency_zipcode IN VARCHAR);

    PROCEDURE CREATE_REQUEST_PP(p_request_number OUT INTEGER, -- an output parameter1
                                p_request_title IN VARCHAR, -- Must not be NULL
                                p_request_description IN VARCHAR, -- Must not be NULL
                                p_request_zipcode IN VARCHAR, -- Must not be NULL
                                p_request_children_served IN INTEGER, -- If there is a value, it must be >= 0
                                p_request_adults_served IN INTEGER, -- If there is a value, it must be >= 0
                                p_request_estimated_value IN NUMBER, -- If there is a value, it must be >= 0
                                p_request_status IN VARCHAR, -- Default to 'open'
                                p_request_create_date IN DATE, -- If a date is not provided, use CURRENT_DATE
                                p_tier_number IN INTEGER, -- Must not be NULL
                                p_county_name IN VARCHAR, -- Must not be NULL
                                p_agency_id IN INTEGER, -- Must not be NULL
                                p_state_code IN CHAR -- Must not be NULL
    );

    PROCEDURE CREATE_NEED_PP(p_need_id OUT INTEGER,
                             p_name IN VARCHAR, -- Must not be NULL
                             p_value IN INTEGER, -- Must not be NULL
                             p_units_requested IN NUMBER,
                             p_request_number IN INTEGER -- Must not be NULL.  Must match existing request in CP_REQUEST
    );

    PROCEDURE CREATE_CHURCH_PP(p_church_id OUT INTEGER,
                               p_name IN VARCHAR, -- Must not be NULL
                               p_street_address IN VARCHAR,
                               p_city IN VARCHAR, -- Must not be NULL
                               p_postal_code IN VARCHAR,
                               p_website IN VARCHAR,
                               p_ein_number IN VARCHAR, -- Must be unique
                               p_affiliation IN VARCHAR,
                               p_avg_attendance IN INTEGER, -- Any value must be >= 0
                               p_location_type IN VARCHAR, -- Any value must be in {'rural', 'suburban', 'urban')
                               p_economic_conditions IN VARCHAR, -- See table constraints for list of allowable values
                               p_heard_about IN VARCHAR, -- See table constraints for list of allowable values
                               p_features_of_interest IN VARCHAR);

    PROCEDURE CREATE_PERSON_PP(p_person_id OUT CP_PERSON.PERSON_ID%TYPE,
                               p_first_name IN CP_PERSON.PERSON_FIRST_NAME%TYPE,
                               p_last_name IN CP_PERSON.PERSON_LAST_NAME%TYPE, -- Must not be NULL
                               p_email IN CP_PERSON.PERSON_EMAIL%TYPE,
                               p_phone IN CP_PERSON.PERSON_PHONE%TYPE,
                               p_church_id IN CP_CHURCH.CHURCH_ID%TYPE -- Must match a church found in CP_CHURCH
    );

    PROCEDURE CREATE_AGENCY_ACCOUNT_PP(p_person_id IN CP_AGENCY_ACCOUNT.PERSON_ID%TYPE,
                                       p_agency_id IN CP_AGENCY_ACCOUNT.AGENCY_ID%TYPE);

    PROCEDURE CREATE_PERSON_PP(p_person_id OUT CP_ACCOUNT.PERSON_ID%TYPE,
                               p_password IN CP_ACCOUNT.ACCOUNT_PASSWORD%TYPE, -- Must not be NULL. Checked inside CREATE_PERSON_PP()
                               p_zipcode IN CP_ACCOUNT.ACCOUNT_ZIPCODE%TYPE,
                               p_first_name IN CP_PERSON.PERSON_FIRST_NAME%TYPE,
                               p_last_name IN CP_PERSON.PERSON_LAST_NAME%TYPE, -- Must not be NULL. Checked inside CREATE_PERSON_PP()
                               p_email IN CP_PERSON.PERSON_EMAIL%TYPE,
                               p_phone IN CP_PERSON.PERSON_PHONE%TYPE,
                               p_church_id IN CP_CHURCH.CHURCH_ID%TYPE -- Must match a church found in CP_CHURCH
    );

    FUNCTION STILL_NEEDED_PF(
        p_need_id IN CP_NEED.NEED_ID%TYPE
    ) RETURN NUMBER;

    PROCEDURE ADD_TO_CART_PP(p_person_id IN INTEGER, -- Must not be NULL; must match person_id value CP_ACCOUNT table
                             p_need_id IN INTEGER, -- Must not be NULL; must match need in CP_NEED table
                             p_quantity IN INTEGER -- Must not be NULL
    );

    PROCEDURE REMOVE_FROM_CART_PP(p_person_id IN INTEGER, -- Must not be NULL;
                                  p_need_id IN INTEGER -- Must not be NULL;
    );

    PROCEDURE REMOVE_FROM_CART_PP(p_person_id IN INTEGER, -- Must not be NULL;
                                  p_need_id IN INTEGER, -- Must not be NULL;
                                  p_quantity IN INTEGER -- Quantity of units to remove.
    );

    PROCEDURE VIEW_CART_PP(
        p_person_id IN INTEGER --NOT NULL
    );

    PROCEDURE CHECKOUT_PP(p_person_id IN NUMBER, --NOT NULL
                          p_order_id OUT NUMBER);

    FUNCTION COUNTY_STATS_PF(p_county_name IN VARCHAR, -- NOT NULL
                             p_state_code IN VARCHAR, -- NOT NULL
                             p_statistic IN VARCHAR -- NOT NULL.   Options are described above.
    ) RETURN INTEGER;

    PROCEDURE CLOSE_REQUEST_PP(
        p_request_number IN INTEGER
    );

END CAREPORTAL3B_PKG;
/

create or replace PACKAGE BODY CAREPORTAL3B_PKG
IS
    -- 1. CREATE_AGENCY_PP
    PROCEDURE CREATE_AGENCY_PP(p_agency_id OUT INTEGER, -- an output parameter
                               p_agency_name IN VARCHAR, -- Must not be NULL
                               p_agency_abbreviation IN VARCHAR,
                               p_agency_website IN VARCHAR,
                               p_agency_email IN VARCHAR, -- Must not be NULL
                               p_agency_email_domain IN VARCHAR,
                               p_agency_address_1 IN VARCHAR,
                               p_agency_address_2 IN VARCHAR,
                               p_agency_city IN VARCHAR, -- Must not be NULL
                               p_state_code IN CHAR, -- Must not be NULL
                               p_agency_type IN VARCHAR,
                               p_agency_zipcode IN VARCHAR)
        IS
        lv_state_code varchar2(2);
    BEGIN
        IF p_agency_name IS NULL
        THEN
            pex_error_txt := 'Missing mandatory value for
        parameter: ' || p_agency_name || ' in CREATE_AGENCY_PP. No agency added.';
            RAISE pex_error;
        END IF;

        IF p_agency_email IS NULL
        THEN
            pex_error_txt := 'Missing mandatory value for
        parameter: ' || p_agency_email || ' in CREATE_AGENCY_PP. No agency added.';
            RAISE pex_error;
        END IF;

        IF p_agency_city IS NULL
        THEN
            pex_error_txt := 'Missing mandatory value for
        parameter: ' || p_agency_city || ' in CREATE_AGENCY_PP. No agency added.';
            RAISE pex_error;
        END IF;

        SELECT STATE_CODE INTO lv_state_code FROM CP_STATE WHERE STATE_CODE = UPPER(p_state_code);
        IF lv_state_code IS NULL
        THEN
            pex_error_txt := 'Invalid state code: ' || p_state_code;
            RAISE pex_error;
        END IF;

        IF p_agency_address_1 = p_agency_address_2
        THEN
            pex_error_txt := 'Both addresses can not be the same value';
            RAISE pex_error;
        END IF;

        IF p_agency_type IS NULL
            OR (p_agency_type) NOT IN
               ('State or County Public Assistance', 'Non-Profit Child Serving', 'State or County Child Welfare')
        THEN
            pex_error_txt := 'The value given: ' || p_agency_type || ' is not a valid agency type';
            RAISE pex_error;
        END IF;

        INSERT INTO CP_AGENCY (AGENCY_ID, AGENCY_NAME,
                               AGENCY_ABBREVIATION, AGENCY_WEBSITE,
                               AGENCY_DESIGNATED_EMAIL,
                               AGENCY_EMAIL_DOMAIN, AGENCY_ADDRESS_1,
                               AGENCY_ADDRESS_2, AGENCY_CITY,
                               STATE_CODE, AGENCY_TYPE, AGENCY_ZIPCODE)
        VALUES ((select max(AGENCY_ID) + 1 FROM CP_AGENCY),
                p_agency_name, p_agency_abbreviation, p_agency_website,
                p_agency_email, p_agency_email_domain,
                p_agency_address_1, p_agency_address_2,
                p_agency_city, p_state_code, p_agency_type,
                p_agency_zipcode)
        RETURNING AGENCY_ID into p_agency_id;
        COMMIT;
    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            ROLLBACK;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            ROLLBACK;
    END CREATE_AGENCY_PP;

    -- 2. CREATE_REQUEST_PP
    PROCEDURE CREATE_REQUEST_PP(p_request_number OUT INTEGER, -- an output parameter
                                p_request_title IN VARCHAR, -- Must not be NULL
                                p_request_description IN VARCHAR,-- Must not be NULL
                                p_request_zipcode IN VARCHAR, --Must not be NULL
                                p_request_children_served IN INTEGER, -- If there is a value, it must be >= 0
                                p_request_adults_served IN INTEGER,-- If there is a value, it must be >= 0
                                p_request_estimated_value IN NUMBER, -- If there is a value, it must be >= 0
                                p_request_status IN VARCHAR, --Default to 'open'
                                p_request_create_date IN DATE, --If a date is not provided, use CURRENT_DATE
                                p_tier_number IN INTEGER, -- Must not be NULL
                                p_county_name IN VARCHAR, -- Must not be NULL
                                p_agency_id IN INTEGER, -- Must not be NULL
                                p_state_code IN CHAR -- Must not be NULL
    )
        IS
        lv_agency_id INTEGER;
    BEGIN
        IF p_request_title IS NULL
        THEN
            pex_error_txt := 'Missing mandatory value in p_request_title';
            RAISE pex_error;
        END IF;

        IF p_state_code IS NULL
        THEN
            pex_error_txt := 'Invalid state code ' || p_state_code;
            RAISE pex_error;
        END IF;

        IF p_county_name IS NULL
        THEN
            pex_error_txt := 'Invalid county ' || p_county_name;
            RAISE pex_error;
        END IF;

        IF p_agency_id IS NOT NULL THEN
            SELECT CP_AGENCY.AGENCY_ID INTO lv_agency_id FROM CP_AGENCY WHERE CP_AGENCY.AGENCY_ID = p_agency_id;
        ELSE
            pex_error_txt := 'Missing parameter Agency_ID';
            RAISE pex_error;
        END IF;

        IF lv_agency_id = 0 OR NULL
        THEN
            pex_error_txt := 'Agency with id : "' || p_agency_id || '" does not exist.';
            RAISE pex_error;
        END IF;

        IF p_tier_number IS NULL
        THEN
            pex_error_txt := 'Invalid tier ' || p_tier_number;
            RAISE pex_error;
        END IF;

        IF p_request_status IS NULL
            OR LOWER(p_request_status)
               NOT IN ('open', 'closed')
        THEN
            pex_error_txt := 'Invalid request status. Status must be open, closed, or NULL';
            RAISE pex_error;
        END IF;

        INSERT INTO CP_REQUEST (REQUEST_NUMBER, REQUEST_TITLE,
                                REQUEST_DESCRIPTION, REQUEST_ZIPCODE,
                                REQUEST_CHILDREN_SERVED,
                                REQUEST_ADULTS_SERVED,
                                REQUEST_ESTIMATED_VALUE, REQUEST_STATUS, REQUEST_CREATE_DATE,
                                TIER_NUMBER, COUNTY_NAME,
                                AGENCY_ID, STATE_CODE)
        VALUES ((select max(REQUEST_NUMBER) + 1 FROM CP_REQUEST),
                p_request_title, p_request_description,
                p_request_zipcode, p_request_children_served,
                p_request_adults_served, p_request_estimated_value,
                p_request_status,
                p_request_create_date, p_tier_number,
                p_county_name, p_agency_id, p_state_code)
        RETURNING request_number into p_request_number;

        COMMIT;
    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            ROLLBACK;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            ROLLBACK;
    END CREATE_REQUEST_PP;

    -- 3. CREATE_NEED_PP
    procedure CREATE_NEED_PP(p_need_id OUT INTEGER,
                             p_name IN VARCHAR, -- Must not be NULL
                             p_value IN INTEGER, -- Must not be NULL
                             p_units_requested IN NUMBER,
                             p_request_number IN INTEGER -- Must not be NULL. --Must match existing request in CP_REQUEST
    )
        IS
        lv_request_num CP_REQUEST.REQUEST_NUMBER%TYPE := NULL;

    BEGIN

        IF p_name IS NULL THEN
            pex_error_txt := 'Missing mandatory value for parameter p_name in ' || 'CREATE_NEED_PP. No need added.';
            RAISE pex_error;
        END IF;

        IF p_value IS NULL THEN
            pex_error_txt := 'Missing mandatory value for parameter p_value in ' || 'CREATE_NEED_PP. No need added.';
            RAISE pex_error;
        END IF;

        IF p_request_number IS NULL THEN
            pex_error_txt := 'Missing mandatory value for parameter ' ||
                             'p_request_number in CREATE_NEED_PP. No need added.';
            RAISE pex_error;
        END IF;

        IF p_units_requested < 0 THEN
            pex_error_txt := 'Need units requested must be greater than or equal to zero';
            RAISE pex_error;
        END IF;

        SELECT REQUEST_NUMBER
        INTO lv_request_num
        FROM CP_REQUEST
        WHERE REQUEST_NUMBER = p_request_number;
        IF lv_request_num IS NULL THEN
            pex_error_txt := 'Request number not found in CP_REQUEST! Need not added.';
            RAISE pex_error;
        END IF;

        INSERT INTO CP_NEED (NEED_ID, NEED_NAME, NEED_VALUE, NEED_UNITS_REQUESTED, REQUEST_NUMBER)
        VALUES ((select max(NEED_ID) + 1 FROM CP_NEED), p_name, p_value, p_units_requested, p_request_number)
        RETURNING NEED_ID INTO p_need_id;

        COMMIT;

    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            ROLLBACK;

        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Oops, something went wrong. Check the error code ' || 'and message: ');
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            ROLLBACK;

    END CREATE_NEED_PP;

-- 4. CREATE_CHURCH_PP
    procedure CREATE_CHURCH_PP(p_church_id OUT INTEGER,
                               p_name IN VARCHAR, --Must not be NULL
                               p_street_address IN VARCHAR,
                               p_city IN VARCHAR, -- Must not be NULL
                               p_postal_code IN VARCHAR,
                               p_website IN VARCHAR,
                               p_ein_number IN VARCHAR, -- Must be unique
                               p_affiliation IN VARCHAR,
                               p_avg_attendance IN INTEGER, -- Any value must be >= 0
                               p_location_type IN VARCHAR, -- Any value must be in {'rural', 'suburban', 'urban')
                               p_economic_conditions IN VARCHAR, -- See table constraints for -- list of allowable values
                               p_heard_about IN VARCHAR, -- See table constraints for -- list of allowable values
                               p_features_of_interest IN VARCHAR)
        IS
        lv_ein_number_count INTEGER := 0;
    BEGIN
        IF p_name IS NULL THEN
            pex_error_txt :=
                        'Missing mandatory value for parameter p_name in ' || 'CREATE_CHURCH_PP. No church added.';
            RAISE pex_error;
        END IF;
        IF p_city IS NULL THEN
            pex_error_txt :=
                        'Missing mandatory value for parameter p_city in ' || 'CREATE_CHURCH_PP. No church added.';
            RAISE pex_error;
        END IF;
        IF p_location_type NOT IN ('rural', 'suburban', 'urban') THEN
            pex_error_txt := 'Invalid value ' || p_location_type || ' for ' || 'church_location_type.';
            RAISE pex_error;
        END IF;
        IF p_economic_conditions NOT IN ('concentrated poverty', 'high income', 'low income', 'middle income') THEN
            pex_error_txt := 'Invalid value ' || p_economic_conditions || ' for ' || 'church_economic_conditions';
            RAISE pex_error;
        END IF;
        IF p_avg_attendance < 0 THEN
            pex_error_txt := 'Church average attendance must be greater than or ' || 'equal to zero';
            RAISE pex_error;
        END IF;
        IF p_heard_about NOT IN
           ('agency contact', 'another church', 'another ministry', 'another way', 'careportal team',
            'someone in my church')
        THEN
            pex_error_txt := 'Invalid value ' || p_heard_about || ' for ' || 'church_heard_about';
            RAISE pex_error;
        END IF;

        SELECT count(*)
        INTO lv_ein_number_count
        FROM CP_CHURCH
        WHERE CHURCH_EIN_NUMBER = p_ein_number;
        IF lv_ein_number_count >= 1 THEN
            pex_error_txt := 'The Church EIN ' || p_ein_number || 'already exists. EIN numbers are unique';
            RAISE pex_error;
        END IF;

        INSERT INTO CP_CHURCH (CHURCH_ID, CHURCH_NAME, CHURCH_CITY,
                               CHURCH_STREET_ADDRESS, CHURCH_POSTAL_CODE,
                               CHURCH_WEBSITE, CHURCH_EIN_NUMBER,
                               CHURCH_AFFILIATION, CHURCH_AVERAGE_ATTENDANCE,
                               CHURCH_LOCATION_TYPE,
                               CHURCH_ECONOMIC_CONDITIONS,
                               CHURCH_HEARD_ABOUT,
                               CHURCH_FEATURES_OF_INTEREST)
        VALUES ((select max(CHURCH_ID) + 1 FROM CP_CHURCH), p_name,
                p_city, p_street_address, p_postal_code, p_website,
                p_ein_number, p_affiliation, p_avg_attendance,
                p_location_type, p_economic_conditions, p_heard_about,
                p_features_of_interest)
        RETURNING CHURCH_ID INTO p_church_id;

        COMMIT;

    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            ROLLBACK;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Oops, something went wrong. Check the error code ' || 'and message: ');
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            ROLLBACK;
    END CREATE_CHURCH_PP;

    -- 5. CREATE_PERSON_PP
    PROCEDURE CREATE_PERSON_PP(p_person_id OUT CP_PERSON.PERSON_ID%TYPE,
                               p_first_name IN CP_PERSON.PERSON_FIRST_NAME%TYPE,
                               p_last_name IN CP_PERSON.PERSON_LAST_NAME%TYPE, -- Must not be NULL
                               p_email IN CP_PERSON.PERSON_EMAIL%TYPE,
                               p_phone IN CP_PERSON.PERSON_PHONE%TYPE,
                               p_church_id IN CP_CHURCH.CHURCH_ID%TYPE -- Must match a church found in
    )
        IS
        lv_church_id CP_CHURCH.CHURCH_ID%TYPE;
    BEGIN
        IF p_last_name IS NULL THEN
            pex_error_txt := 'Last name invalid or NULL';
            RAISE pex_error;
        END IF;

        IF p_church_id IS NOT NULL
        THEN
            SELECT church_id
            INTO lv_church_id
            FROM CP_CHURCH
            WHERE church_id = p_church_id;
            IF lv_church_id IS NULL
            THEN
                pex_error_txt := 'Church with id ' || p_church_id || ' does not exist.';
                RAISE pex_error;
            END IF;

            INSERT INTO CP_PERSON(PERSON_ID, PERSON_FIRST_NAME, PERSON_LAST_NAME, PERSON_EMAIL, PERSON_PHONE,
                                  CHURCH_CHURCH_ID)
            VALUES ((select max(PERSON_ID) + 1 FROM CP_PERSON),
                    p_first_name, p_last_name, p_email, p_phone, lv_church_id)
            RETURNING PERSON_ID INTO p_person_id;
        END IF;

        COMMIT;

    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            DBMS_OUTPUT.PUT_LINE('Error number :' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message ' || SQLERRM);
            ROLLBACK;

        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred.');
            DBMS_OUTPUT.PUT_LINE('Error number :' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message ' || SQLERRM);
            ROLLBACK;
    END CREATE_PERSON_PP;

    -- 6. CREATE_AGENCY_ACCOUNT_PP
    PROCEDURE CREATE_AGENCY_ACCOUNT_PP(p_person_id IN CP_AGENCY_ACCOUNT.PERSON_ID%TYPE,
                                       p_agency_id IN CP_AGENCY_ACCOUNT.AGENCY_ID%TYPE)
        IS
        lv_agencyID_num CP_AGENCY.AGENCY_ID%TYPE := NULL;
        lv_personID_num CP_PERSON.PERSON_ID%TYPE := NULL;
        lv_count_num    INTEGER                  := NULL;
    BEGIN
        IF p_agency_id IS NULL
        THEN
            pex_error_txt := 'Agency ID cannot be NULL. Please provide new a value';
            RAISE pex_error;
        END IF;

        IF p_person_id IS NULL
        THEN
            pex_error_txt := 'Person ID cannot be NULL. Please provide new a value.';
            RAISE pex_error;
        END IF;

        SELECT count(*)
        INTO lv_count_num
        FROM CP_ACCOUNT
        WHERE PERSON_ID = p_person_id;
        IF lv_count_num = 0
        THEN
            pex_error_txt := 'Person: ' || p_person_id || ' not found.';
            RAISE pex_error;
        END IF;

        SELECT count(*)
        INTO lv_count_num
        FROM CP_AGENCY
        WHERE AGENCY_ID = p_agency_id;
        IF lv_count_num = 0
        THEN
            pex_error_txt := 'Agency: ' || p_agency_id || ' not found.';
            RAISE pex_error;

        END IF;

        SELECT CP_PERSON.PERSON_ID
        INTO lv_personID_num
        FROM CP_PERSON
        WHERE PERSON_ID = p_person_id;

        SELECT CP_AGENCY.AGENCY_ID
        INTO lv_agencyID_num
        FROM CP_AGENCY
        WHERE AGENCY_ID = p_agency_id;

        INSERT INTO CP_AGENCY_ACCOUNT (PERSON_ID, AGENCY_ID)
        VALUES (lv_personID_num, lv_agencyID_num);
        COMMIT;

    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            ROLLBACK;

        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ops, something went wrong. Check the error code and message: ');
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            ROLLBACK;
    END CREATE_AGENCY_ACCOUNT_PP;

    -- 7. CREATE_PERSON (OVERLOAD)
    PROCEDURE CREATE_PERSON_PP(p_person_id OUT CP_ACCOUNT.PERSON_ID%TYPE,
                               p_password IN CP_ACCOUNT.ACCOUNT_PASSWORD%TYPE, -- Must not be NULL. Checked inside CREATE_PERSON_PP()
                               p_zipcode IN CP_ACCOUNT.ACCOUNT_ZIPCODE%TYPE,
                               p_first_name IN CP_PERSON.PERSON_FIRST_NAME%TYPE,
                               p_last_name IN CP_PERSON.PERSON_LAST_NAME%TYPE, -- Must not be NULL. Checked inside CREATE_PERSON_PP()
                               p_email IN CP_PERSON.PERSON_EMAIL%TYPE,
                               p_phone IN CP_PERSON.PERSON_PHONE%TYPE,
                               p_church_id IN CP_CHURCH.CHURCH_ID%TYPE -- Must match a church found in CP_CHURCH. Checked inside CREATE_PERSON_PP()
    )
        IS
    BEGIN
        IF p_password IS NULL THEN
            pex_error_txt := 'Password invalid or NULL';
            RAISE pex_error;

        ELSE
            CAREPORTAL3B_PKG.CREATE_PERSON_PP(p_person_id, p_first_name, p_last_name, p_email, p_phone, p_church_id);
            IF p_person_id IS NULL THEN
                pex_error_txt := 'INVALID person_id. Error at create_person_PP';
                RAISE pex_error;
            ELSE
                INSERT INTO CP_ACCOUNT(PERSON_ID, ACCOUNT_PASSWORD, ACCOUNT_ZIPCODE)
                VALUES (p_person_id, p_password, p_zipcode)
                RETURNING PERSON_ID INTO p_person_id;
            END IF;
        END IF;
        COMMIT;
    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            DBMS_OUTPUT.PUT_LINE('Error number     :' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message    ' || SQLERRM);
            ROLLBACK;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred.');
            DBMS_OUTPUT.PUT_LINE('Error number     :' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message    ' || SQLERRM);
            ROLLBACK;
    END CREATE_PERSON_PP;

    -- 8. STILL_NEEDED_PF
    FUNCTION STILL_NEEDED_PF(
        p_need_id IN CP_NEED.NEED_ID%TYPE
    ) RETURN NUMBER
        IS
        lv_units_contributed  CP_CONTRIBUTION_DETAIL.CD_QUANTITY%TYPE;
        lv_units_requested    CP_NEED.NEED_UNITS_REQUESTED%TYPE;
        lv_units_still_needed NUMBER := 0;
    BEGIN
        IF p_need_id IS NULL THEN
            pex_error_txt := 'Missing mandatory value for parameter p_need_id in NEED_ID';
            RAISE pex_error;
        END IF;

        SELECT CP_NEED.NEED_UNITS_REQUESTED
        INTO lv_units_requested
        FROM CP_NEED
        WHERE CP_NEED.NEED_ID = p_need_id;

        SELECT SUM(CP_CONTRIBUTION_DETAIL.CD_QUANTITY)
        INTO lv_units_contributed
        FROM CP_CONTRIBUTION_DETAIL
        WHERE CP_CONTRIBUTION_DETAIL.NEED_ID = p_need_id;

        IF lv_units_contributed IS NULL THEN
            lv_units_still_needed := lv_units_requested;
        ELSE
            lv_units_still_needed := lv_units_requested - lv_units_contributed;
        END IF;

        IF lv_units_still_needed < 0
        THEN
            pex_error_txt := 'Units still needed is less than 0';
            RAISE pex_error;
        END IF;
        DBMS_OUTPUT.PUT_LINE('items still needed: ' || lv_units_still_needed);
        IF lv_units_still_needed IS NULL
        THEN
            lv_units_still_needed := 0;
        END IF;

        RETURN lv_units_still_needed;
    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            DBMS_OUTPUT.PUT_LINE('Error number :' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message ' || SQLERRM);
            RETURN NULL;
            ROLLBACK;

        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred.');
            DBMS_OUTPUT.PUT_LINE('Error number :' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message ' || SQLERRM);
            RETURN NULL;
            ROLLBACK;
    END STILL_NEEDED_PF;

    -- 9. ADD_TO_CART_PP
    PROCEDURE ADD_TO_CART_PP(p_person_id IN INTEGER, -- Must not be NULL; must match person_id value CP_ACCOUNT table
                             p_need_id IN INTEGER, -- Must not be NULL; must match need in CP_NEED table
                             p_quantity IN INTEGER -- Must not be NULL
    )
        IS
        lv_item_count       NUMBER := 0;
        lv_items_in_cart    NUMBER := 0;
        lv_person_id        NUMBER;
        lv_still_needed_num NUMBER := 0;
        lv_items_total      NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('AddToCart_pp');
        DBMS_OUTPUT.PUT_LINE('p_person_id: ' || p_person_id);
        DBMS_OUTPUT.PUT_LINE('p_need_id: ' || p_need_id);
        DBMS_OUTPUT.PUT_LINE('p_quantity: ' || p_quantity);

        IF p_quantity < 1 THEN
            pex_error_txt := 'Error: Quantity is less than one.';
            RAISE pex_error;
        END IF;

        SELECT count(CART_ITEM_ID)
        INTO lv_item_count
        FROM CP_CART_ITEM
        WHERE CP_CART_ITEM.NEED_ID = p_need_id
          AND CP_CART_ITEM.PERSON_ID = p_person_id;
        IF lv_item_count > 0
        THEN
            SELECT CART_QUANTITY
            INTO lv_items_in_cart
            FROM CP_CART_ITEM
            WHERE CP_CART_ITEM.PERSON_ID = p_person_id
              AND CP_CART_ITEM.NEED_ID = p_need_id;
        END IF;

        lv_still_needed_num := CAREPORTAL3B_PKG.STILL_NEEDED_PF(p_need_id);
        DBMS_OUTPUT.PUT_LINE('Items still needed: ' || lv_still_needed_num);
        lv_items_total := lv_items_in_cart + p_quantity;
        IF lv_still_needed_num < lv_items_total THEN
            pex_error_txt :=
                        'Error:\nStill needed: ' || lv_still_needed_num || '\nAlready in cart: ' || lv_items_in_cart ||
                        '\nCannot add: ' || p_quantity;
            RAISE pex_error;
        ELSE
            SELECT PERSON_ID
            INTO lv_person_id
            FROM CP_ACCOUNT
            WHERE PERSON_ID = p_person_id;
            IF lv_person_id IS NULL THEN
                pex_error_txt := 'Error: Person is NULL or does not exist.';
                RAISE pex_error;
            END IF;

            IF lv_items_in_cart > 0
            THEN
                UPDATE CP_CART_ITEM
                SET CART_QUANTITY = p_quantity + lv_items_in_cart
                WHERE PERSON_ID = p_person_id
                  AND NEED_ID = p_need_id;
                COMMIT;
            ELSE
                INSERT INTO CP_CART_ITEM (NEED_ID, CART_QUANTITY, PERSON_ID)
                VALUES (p_need_id, p_quantity, p_person_id);
                COMMIT;
            END IF;
        END IF;
    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            ROLLBACK;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred.');
            DBMS_OUTPUT.PUT_LINE('Error number     :' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message    ' || SQLERRM);
            ROLLBACK;
    END ADD_TO_CART_PP;

    -- 10. REMOVE_FROM_CART_PP
    PROCEDURE REMOVE_FROM_CART_PP(p_person_id IN INTEGER, -- Must not be NULL;
                                  p_need_id IN INTEGER -- Must not be NULL;
    )
        IS
        lv_cart_item_id NUMBER;
    BEGIN
        IF p_person_id IS NULL
        THEN
            pex_error_txt := 'Missing parameter PERSON_ID';
            RAISE pex_error;
        END IF;

        IF p_need_id IS NULL
        THEN
            pex_error_txt := 'Missing parameter NEED_ID';
            RAISE pex_error;
        END IF;

        SELECT CART_ITEM_ID
        INTO lv_cart_item_id
        FROM CP_CART_ITEM
        WHERE PERSON_ID = p_person_id
          AND NEED_ID = p_need_id;
        IF lv_cart_item_id IS NULL THEN
            pex_error_txt := 'Need "' || p_need_id || '" does not exist in cart of ' || p_person_id;
            RAISE pex_error;
        ELSE
            DELETE FROM CP_CART_ITEM WHERE CP_CART_ITEM.CART_ITEM_ID = lv_cart_item_id;
            COMMIT;
        END IF;
    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            ROLLBACK;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred.');
            DBMS_OUTPUT.PUT_LINE('Error number     :' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message    ' || SQLERRM);
            ROLLBACK;
    END REMOVE_FROM_CART_PP;

    -- 10. REMOVE_FROM_CART_PP (OVERLOADED)
    PROCEDURE REMOVE_FROM_CART_PP(p_person_id IN INTEGER, -- Must not be NULL;
                                  p_need_id IN INTEGER, -- Must not be NULL;
                                  p_quantity IN INTEGER -- Quantity of units to remove.
    )
        IS
        lv_cart_item_id       NUMBER;
        lv_cart_item_quantity NUMBER;
    BEGIN
        IF p_person_id IS NULL
        THEN
            pex_error_txt := 'Missing parameter PERSON_ID';
            RAISE pex_error;
        END IF;

        IF p_need_id IS NULL
        THEN
            pex_error_txt := 'Missing parameter NEED_ID';
            RAISE pex_error;
        END IF;
        IF p_quantity IS NULL
        THEN
            pex_error_txt := 'Missing parameter Quantity';
            RAISE pex_error;
        END IF;

        SELECT CART_ITEM_ID, CART_QUANTITY
        INTO lv_cart_item_id, lv_cart_item_quantity
        FROM CP_CART_ITEM
        WHERE PERSON_ID = p_person_id
          AND NEED_ID = p_need_id;

        IF lv_cart_item_id IS NULL THEN
            pex_error_txt := 'Need "' || p_need_id || '" does not exist in cart of ' || p_person_id;
            RAISE pex_error;
        ELSIF lv_cart_item_quantity < p_quantity
        THEN
            DBMS_OUTPUT.PUT_LINE('Higher quantity than in cart. Removing item(s) from cart.');
            DELETE FROM CP_CART_ITEM WHERE CP_CART_ITEM.CART_ITEM_ID = lv_cart_item_id;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Removing ' || p_quantity || ' from cart of need: ' || p_need_id);
            UPDATE CP_CART_ITEM
            SET CP_CART_ITEM.CART_QUANTITY = lv_cart_item_quantity - p_quantity
            WHERE CP_CART_ITEM.CART_ITEM_ID = lv_cart_item_id;
            DBMS_OUTPUT.PUT_LINE(p_quantity || ' removed from cart.');
        END IF;

        COMMIT;
    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            ROLLBACK;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred.');
            DBMS_OUTPUT.PUT_LINE('Error number     :' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message    ' || SQLERRM);
            ROLLBACK;
    END REMOVE_FROM_CART_PP;

-- 11. VIEW_CART_PP
    PROCEDURE VIEW_CART_PP(
        p_person_id IN INTEGER --NOT NULL
    )
        IS
        CURSOR cur_cart_items IS
            SELECT CP_NEED.REQUEST_NUMBER,
                   CP_NEED.NEED_NAME,
                   CP_CART_ITEM.CART_QUANTITY,
                   CP_NEED.NEED_VALUE,
                   CP_CART_ITEM.CART_QUANTITY * CP_NEED.NEED_VALUE AS TOTAL_VALUE
            FROM CP_CART_ITEM,
                 CP_REQUEST,
                 CP_NEED
            WHERE PERSON_ID = p_person_id
              AND CP_CART_ITEM.NEED_ID = CP_NEED.NEED_ID
              AND CP_NEED.REQUEST_NUMBER = CP_REQUEST.REQUEST_NUMBER
            GROUP BY CP_NEED.REQUEST_NUMBER, CP_NEED.NEED_NAME, CP_CART_ITEM.CART_QUANTITY, CP_NEED.NEED_VALUE,
                     CP_CART_ITEM.CART_QUANTITY * CP_NEED.NEED_VALUE;
        rec_shopping_cart cur_cart_items%ROWTYPE;
        lv_cart_total     NUMBER := 0;
    BEGIN
        OPEN cur_cart_items;
        LOOP
            FETCH cur_cart_items INTO rec_shopping_cart;
            EXIT WHEN cur_cart_items%NOTFOUND;
            lv_cart_total := lv_cart_total + rec_shopping_cart.TOTAL_VALUE;
            DBMS_OUTPUT.PUT_LINE('Request Number: ' || rec_shopping_cart.REQUEST_NUMBER);
            DBMS_OUTPUT.PUT_LINE('Need Name: ' || rec_shopping_cart.NEED_NAME);
            DBMS_OUTPUT.PUT_LINE('Quantity: ' || rec_shopping_cart.CART_QUANTITY);
            DBMS_OUTPUT.PUT_LINE('Total Value: ' || rec_shopping_cart.TOTAL_VALUE);
            DBMS_OUTPUT.PUT_LINE('Item number ' || cur_cart_items%ROWCOUNT);
            DBMS_OUTPUT.PUT_LINE('|--------------|');
        END LOOP;
        IF cur_cart_items%ROWCOUNT < 1 THEN
            pex_error_txt := 'There are no items in the cart.';
            RAISE pex_error;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Total of all items: ' || lv_cart_total);
        CLOSE cur_cart_items;
    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            ROLLBACK;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred.');
            DBMS_OUTPUT.PUT_LINE('Error number     :' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message    ' || SQLERRM);
            ROLLBACK;
    END VIEW_CART_PP;

    -- 12. CHECKOUT_PP
    PROCEDURE CHECKOUT_PP(p_person_id IN NUMBER, --NOT NULL
                          p_order_id OUT NUMBER)
        IS
        lv_contribution_number NUMBER;
        lv_needs_left          NUMBER;
        lv_cart_total          NUMBER := 0;
        CURSOR cur_cart_items IS
            SELECT CP_NEED.REQUEST_NUMBER,
                   CP_NEED.NEED_ID,
                   CP_CART_ITEM.CART_QUANTITY,
                   CP_NEED.NEED_VALUE,
                   CP_CART_ITEM.CART_QUANTITY * CP_NEED.NEED_VALUE AS TOTAL_VALUE
            FROM CP_NEED,
                 CP_REQUEST,
                 CP_CART_ITEM
            WHERE PERSON_ID = p_person_id
              AND CP_NEED.NEED_ID = CP_CART_ITEM.NEED_ID
              AND CP_NEED.REQUEST_NUMBER = CP_REQUEST.REQUEST_NUMBER
            GROUP BY CP_NEED.REQUEST_NUMBER, CP_NEED.NEED_ID, CP_CART_ITEM.CART_QUANTITY, CP_NEED.NEED_VALUE,
                     CP_CART_ITEM.CART_QUANTITY * CP_NEED.NEED_VALUE;
        rec_shopping_cart      cur_cart_items%ROWTYPE;
    BEGIN

        IF p_person_id IS NULL THEN
            pex_error_txt := 'An error has occurred, person_id invalid or missing.';
            RAISE pex_error;
        END IF;
        SELECT max(CONTRIBUTION_NUMBER) + 1 INTO lv_contribution_number FROM CP_CONTRIBUTION;

        IF lv_contribution_number IS NULL THEN
            pex_error_txt := 'An unexpected error has occurred, contribution_number not retrievable.';
            RAISE pex_error;
        END IF;

        OPEN cur_cart_items;
        LOOP
            FETCH cur_cart_items INTO rec_shopping_cart;
            EXIT WHEN cur_cart_items%NOTFOUND;
            lv_needs_left := CAREPORTAL3B_PKG.STILL_NEEDED_PF(rec_shopping_cart.NEED_ID);
            IF rec_shopping_cart.CART_QUANTITY <= lv_needs_left THEN
                lv_cart_total := lv_cart_total + rec_shopping_cart.TOTAL_VALUE;
            ELSE
                pex_error_txt := 'NEED_ID: ' || rec_shopping_cart.NEED_ID || '\nRequires ' || lv_needs_left ||
                                 '\nCart quantity is too high: ' || rec_shopping_cart.CART_QUANTITY;
                RAISE pex_error;
            END IF;
        END LOOP;

        INSERT INTO CP_CONTRIBUTION (CONTRIBUTION_NUMBER, CONTRIBUTION_DATE, CONTRIBUTION_TOTAL, PERSON_ID)
        VALUES (lv_contribution_number, CURRENT_DATE, lv_cart_total, p_person_id);
        DBMS_OUTPUT.PUT_LINE('Test 1');
        CLOSE cur_cart_items;

        OPEN cur_cart_items;
        LOOP
            FETCH cur_cart_items INTO rec_shopping_cart;
            EXIT WHEN cur_cart_items%NOTFOUND;
            lv_needs_left := CAREPORTAL3B_PKG.STILL_NEEDED_PF(rec_shopping_cart.NEED_ID);
            IF rec_shopping_cart.CART_QUANTITY <= lv_needs_left THEN
                DBMS_OUTPUT.PUT_LINE('Test LOOP');
                INSERT INTO CP_CONTRIBUTION_DETAIL (CONTRIBUTION_NUMBER, NEED_ID, CD_QUANTITY, CD_UNIT_VALUE,
                                                    CD_TOTAL_VALUE)
                VALUES (lv_contribution_number, rec_shopping_cart.NEED_ID, rec_shopping_cart.CART_QUANTITY,
                        rec_shopping_cart.NEED_VALUE, rec_shopping_cart.TOTAL_VALUE);
                REMOVE_FROM_CART_PP(p_person_id, rec_shopping_cart.NEED_ID);
                CLOSE_REQUEST_PP(rec_shopping_cart.request_number);
            ELSE
                pex_error_txt := 'NEED_ID: ' || rec_shopping_cart.NEED_ID || '\nRequires ' || lv_needs_left ||
                                 '\nCart quantity is too high: ' || rec_shopping_cart.CART_QUANTITY;
                RAISE pex_error;
            END IF;

        END LOOP;

        CLOSE cur_cart_items;

        SELECT CONTRIBUTION_NUMBER
        INTO p_order_id
        FROM CP_CONTRIBUTION
        WHERE CONTRIBUTION_NUMBER = lv_contribution_number;
        COMMIT;
    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            ROLLBACK;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred.');
            DBMS_OUTPUT.PUT_LINE('Error number     :' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message    ' || SQLERRM);
            ROLLBACK;
    END CHECKOUT_PP;

    -- 13. COUNTY_STATS_PF
    FUNCTION COUNTY_STATS_PF(p_county_name IN VARCHAR, -- NOT NULL
                             p_state_code IN VARCHAR, -- NOT NULL
                             p_statistic IN VARCHAR -- NOT NULL.   Options are described above.
    ) RETURN INTEGER
        IS
        lv_requests_open   CP_REQUEST.REQUEST_STATUS%TYPE;
        lv_requests_total  CP_REQUEST.REQUEST_NUMBER%TYPE;
        lv_children_served CP_REQUEST.REQUEST_CHILDREN_SERVED%TYPE;
        lv_total_value     CP_CONTRIBUTION_DETAIL.CD_TOTAL_VALUE%TYPE;
        lv_county_name     CP_COUNTY.COUNTY_NAME%TYPE;
    BEGIN
        IF p_county_name IS NULL THEN
            pex_error_txt := 'Missing mandatory value for parameter p_county_name in COUNTY_STATS_PF.';
            RAISE pex_error;
        END IF;

        IF p_state_code IS NULL THEN
            pex_error_txt := 'Missing mandatory value for parameter p_state_code in COUNTY_STATS_PF.';
            RAISE pex_error;
        END IF;

        IF p_statistic IS NULL THEN
            pex_error_txt := 'Missing mandatory value for parameter p_statistic in COUNTY_STATS_PF.';
            RAISE pex_error;
        END IF;

        SELECT COUNTY_NAME
        INTO lv_county_name
        FROM CP_COUNTY,
             CP_STATE
        WHERE CP_COUNTY.STATE_CODE = p_state_code
          AND CP_COUNTY.COUNTY_NAME = p_county_name
          AND CP_COUNTY.STATE_CODE = CP_STATE.STATE_CODE
        GROUP BY CP_COUNTY.COUNTY_NAME;

        IF lv_county_name IS NULL THEN
            pex_error_txt := 'Invalid county';
            raise pex_error;
        END IF;

        IF p_statistic NOT IN ('total requests', 'open requests', 'total children served', 'economic impact')
        THEN
            pex_error_txt := 'Invalid statistic';
            RAISE pex_error;
        END IF;

        IF p_statistic = 'total requests' THEN
            SELECT COUNT(cp_request.REQUEST_NUMBER)
            INTO lv_requests_total
            FROM CP_REQUEST
            WHERE (cp_request.county_name = p_county_name)
              AND (cp_request.state_code = p_state_code);
            DBMS_OUTPUT.PUT_LINE('Total of requests: ' || lv_requests_total);
            RETURN lv_requests_total;
        END IF;

        IF p_statistic = 'open requests' THEN
            SELECT COUNT(cp_request.REQUEST_NUMBER)
            INTO lv_requests_open
            FROM CP_REQUEST
            WHERE (cp_request.county_name = p_county_name)
              AND (cp_request.state_code = p_state_code)
              AND CP_REQUEST.REQUEST_STATUS = 'open';
            DBMS_OUTPUT.PUT_LINE('Total open requests: ' || lv_requests_open);
            RETURN lv_requests_open;
        END IF;

        If p_statistic LIKE 'total children served' THEN
            SELECT SUM(cp_request.REQUEST_CHILDREN_SERVED)
            INTO lv_children_served
            FROM CP_REQUEST
            WHERE (cp_request.county_name = p_county_name)
              AND (cp_request.state_code = p_state_code);
            DBMS_OUTPUT.PUT_LINE('Total of children served: ' || lv_children_served);
            RETURN lv_children_served;
        END IF;

        IF p_statistic LIKE 'economic impact' THEN
            SELECT SUM(CP_CONTRIBUTION_DETAIL.CD_TOTAL_VALUE)
            INTO lv_total_value
            FROM CP_REQUEST,
                 CP_CONTRIBUTION_DETAIL,
                 CP_NEED
            WHERE cp_request.county_name = p_county_name
              AND cp_request.state_code = p_state_code
              AND cp_request.request_number = cp_need.request_number
              AND cp_need.need_id = cp_contribution_detail.need_id;
            DBMS_OUTPUT.PUT_LINE('Total value: ' || lv_total_value);
            RETURN lv_total_value;
        END IF;


    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            RETURN NULL;
            ROLLBACK;
        WHEN others THEN
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            RETURN NULL;
            ROLLBACK;
    END COUNTY_STATS_PF;

    -- 14. CLOSE_REQUEST_PP
    procedure CLOSE_REQUEST_PP(
        p_request_number IN INTEGER
    )
        IS
        CURSOR needs_in_request_cur IS
            SELECT CP_NEED.NEED_ID, NEED_UNITS_REQUESTED
            FROM CP_NEED
            WHERE CP_NEED.REQUEST_NUMBER = p_request_number;
        rec_needs_in_request       needs_in_request_cur%ROWTYPE;
        lv_still_needed_in_request INTEGER := 0;
    BEGIN
        IF p_request_number IS NULL THEN
            pex_error_txt := 'Missing mandatory value for parameter (request number) in CLOSE_REQUEST_PP.';
            RAISE pex_error;
        END IF;

        OPEN needs_in_request_cur;
        LOOP
            FETCH needs_in_request_cur into rec_needs_in_request;
            EXIT WHEN needs_in_request_cur%NOTFOUND OR lv_still_needed_in_request > 0;
            IF CAREPORTAL3B_PKG.STILL_NEEDED_PF(rec_needs_in_request.NEED_ID) > 0 THEN
                lv_still_needed_in_request := lv_still_needed_in_request + 1;
            END IF;
        END LOOP;

        IF lv_still_needed_in_request = 0
        THEN
            UPDATE CP_REQUEST
            SET REQUEST_STATUS = 'closed'
            WHERE request_number = p_request_number;
            DBMS_OUTPUT.PUT_LINE('Request: ' || p_request_number || '`s needs have been met. Closing Request.');
        ELSE
            pex_error_txt := 'Items are still needed in request: ' || p_request_number;
            RAISE pex_error;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN pex_error THEN
            DBMS_OUTPUT.PUT_LINE(pex_error_txt);
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            ROLLBACK;

        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
            ROLLBACK;
    END CLOSE_REQUEST_PP;
END CAREPORTAL3B_PKG;


