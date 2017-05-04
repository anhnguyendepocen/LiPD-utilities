import numpy as np
import copy
import warnings

from ..helpers.loggers import create_logger

logger_inferred_data = create_logger("inferred_data")


def _get_age(columns):
    """
    Sift through table column data and find the "age" or "year" column. Return its "values" data.
    :param dict columns: Column data
    :return list age: Age values
    """

    # Need to check multiple places for age, year, or yrbp
    # 1. Check the column variable name
    # 2. Check for an "inferredVariableType

    age = []
    try:
        # Step 1:
        # Check for age first (exact match)
        if "age" in columns:
            # Save the values
            age = columns["age"]["values"]
        # Check for year second (exact match)
        elif "year" in columns:
            # Save the values
            age = columns["year"]["values"]
        elif "yrbp" in columns:
            # Save the values
            age = columns["yrbp"]["values"]

        # Step 2 No exact matches, check for an "inferredVariableType" : "Age" or "Year"
        if not age:
            # Loop through column variableNames
            for k, v in columns.items():
                try:
                    if v["inferredVariableType"].lower() == "age":
                        age = v["values"]
                    elif v["inferredVariableType"].lower() == "year":
                        age = v["values"]
                except Exception:
                    # Not too concerned if we error here.
                    pass

        # Step 3: No year or age found, start searching for a loose match with "age" or "year" in the variableName.
        if not age:
            # Loop through column variableNames
            for k, v in columns.items():
                k_low = k.lower()
                # Check for age in the variableName (loose match)
                if "age" in k_low:
                    # Save the values
                    age = v["values"]
                # Check for year in variableName (loose match)
                elif "year" in k_low:
                    # Save the values
                    age = v["values"]
                elif "yrbp" in k_low:
                    # Save the values
                    age = v["values"]



    # If we expected a dictionary, and didn't get one
    except AttributeError as e:
        logger_inferred_data.warn("get_age: AttributeError: {}".format(e))
    # If we were looking for values, and didn't get one
    except KeyError as e:
        logger_inferred_data.warn("get_age: KeyError: {}".format(e))
    # Fail-safe for other problems
    except Exception as e:
        logger_inferred_data.warn("get_age: Exception: {}".format(e))

    return age


def _get_resolution(age, values):
    """
    Calculates the resolution (res)
    Thanks Deborah!
    """
    res = []
    try:
        # Get the nan index from the values and remove from age
        # age2 = age[np.where(~np.isnan(values))[0]]
        # res = np.diff(age2)

        # Make sure that age and values are numpy arrays
        # age = np.array(age, dtype=float)
        # values = np.array(values, dtype=float)
        # Get the nan index from the values and remove from age
        age2 = age[np.where(~np.isnan(values))[0]]
        res = np.diff(age2)

    except IndexError as e:
        print("get_resolution: IndexError: {}".format(e))
    except Exception as e:
        logger_inferred_data.warn("get_resolution: Exception: {}".format(e))
    return res


def _get_inferred_data_res(column, age):
    """
    Calculate Resolution and m/m/m/m for column values.
    :param dict column: Column data
    :param list age: Age values
    :return dict column: Column data - modified
    """
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            # Get the values for this column
            values = column["values"]
            # Make sure that age and values are numpy arrays
            _values = np.array(copy.copy(values), dtype=float)
            _age = np.array(age, dtype=float)
            # If we have values, keep going
            if len(_values) != 0:
                # Get the resolution for this age and column values data
                res = _get_resolution(_age, _values)
                # If we have successful resolution data, keep going
                if len(res) != 0:
                    # Use the resolution values to create new entries and data
                    column["hasResolution"] = {
                        "hasMinValue": np.min(res).tolist(),
                        "hasMaxValue": np.max(res).tolist(),
                        "hasMeanValue": np.mean(res).tolist(),
                        "hasMedianValue": np.median(res).tolist(),
                        # "values": res.tolist()
                    }

                # Remove the NaNs from the values list.
                _values = _values[np.where(~np.isnan(_values))[0]]
                # Use the values to create new entries and data
                column["hasMinValue"] = np.min(_values).tolist()
                column["hasMaxValue"] = np.max(_values).tolist()
                column["hasMedianValue"] = np.median(_values).tolist()
                column["hasMeanValue"] = np.mean(_values).tolist()
    except KeyError as e:
        logger_inferred_data.debug("get_inferred_data_column: KeyError: {}".format(e))
    except Exception as e:
        logger_inferred_data.debug("get_inferred_data_column: Exception: {}".format(e))

    return column


def _get_inferred_data_column(column):
    """
    Calculate the m/m/m/m for column values.
    :param dict column: Column data
    :return dict column: Column data - modified
    """
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            # Get the values for this column
            values = column["values"]
            # Make sure that age and values are numpy arrays
            _values = np.array(copy.copy(values), dtype=float)
            # If we have values, keep going
            if len(_values) != 0:
                # Remove the NaNs from the values list.
                _values = _values[np.where(~np.isnan(_values))[0]]
                # Use the values to create new entries and data
                column["hasMinValue"] = np.min(_values).tolist()
                column["hasMaxValue"] = np.max(_values).tolist()
                column["hasMedianValue"] = np.median(_values).tolist()
                column["hasMeanValue"] = np.mean(_values).tolist()
    except KeyError as e:
        logger_inferred_data.debug("get_inferred_data_column: KeyError: {}".format(e))
    except Exception as e:
        logger_inferred_data.debug("get_inferred_data_column: Exception: {}".format(e))

    return column


def get_inferred_data_table(pc, table):
    """
    Table level: Dive down, calculate data, then return the new table with the inferred data.
    :param str pc: Paleo or Chron table type
    :param dict table: Table data
    :return dict table: Table with new data
    """
    age = None
    if pc == "paleo":
        # Get the age values data first, since it's needed to calculate the other column data.
        age = _get_age(table["columns"])

    try:
        # If age values were not found, then skip resolution.
        if age:
            # Loop for all the columns in the table
            for var, col in table["columns"].items():
                # Special cases
                # We do not calculate data for each of the keys below, and we cannot calculate any "string" data
                if var in ["age", "year"]:
                    # Calculate m/m/m/m, but not resolution
                    table["columns"][var] = _get_inferred_data_column(col)
                elif not all(isinstance(i, str) for i in col["values"]):
                    # Calculate m/m/m/m and resolution
                    table["columns"][var] = _get_inferred_data_res(col, age)
                else:
                    # Fall through case. No calculations made.
                    logger_inferred_data.info("get_inferred_data_table: "
                                              "Not calculating inferred data for variableName: {}".format(var))

        # If there isn't an age, still calculate the m/m/m/m for the column values.
        else:
            for var, col in table["columns"].items():
                if not all(isinstance(i, str) for i in col["values"]):
                    # Calculate m/m/m/m and resolution
                    table["columns"][var] = _get_inferred_data_column(col)
                else:
                    # Fall through case. No calculations made.
                    logger_inferred_data.info("get_inferred_data_table: "
                                              "Not calculating inferred data for variableName: {}".format(var))

    except AttributeError as e:
        logger_inferred_data.warn("get_inferred_data_table: AttributeError: {}".format(e))
    except Exception as e:
        logger_inferred_data.warn("get_inferred_data_table: Exception: {}".format(e))

    return table