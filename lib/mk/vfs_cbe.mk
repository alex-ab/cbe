SRC_CC = vfs.cc

LIBS += cbe_cxx
LIBS += external_crypto_cxx
LIBS += external_trust_anchor_cxx

vpath % $(REP_DIR)/src/lib/vfs/cbe

SHARED_LIB := yes

CC_CXX_WARN_STRICT :=
