{ lib, buildPythonPackage, fetchPypi, PyGithub, python-gitlab }:

buildPythonPackage rec {
  pname = "criticality_score";
  version = "1.0.8";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-5XkVT0blnLG158a01jDfQl1Rx9U1LMsqaMjTdN7Q4QQ=";
  };

  propagatedBuildInputs = [ PyGithub python-gitlab ];

  doCheck = false;

  pythonImportsCheck = [ "criticality_score" ];

  meta = with lib; {
    description = "Python tool for computing the Open Source Project Criticality Score.";
    homepage = "https://github.com/ossf/criticality_score";
    license = licenses.asl20;
    maintainers = with maintainers; [ wamserma ];
  };
}
